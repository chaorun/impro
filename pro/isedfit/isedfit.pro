;+
; NAME:
;   ISEDFIT
;
; PURPOSE:
;   Model the spectral energy distributions of galaxies using
;   population synthesis models to infer their physical properties. 
;
; INPUTS:
;   isedfit_paramfile - iSEDfit parameter file
;   maggies - photometry [NFILT,NGAL]
;   ivarmaggies - inverse variance array for MAGGIES [NFILT,NGAL]  
;   zobj - galaxy redshift [NGAL] 
;
; OPTIONAL INPUTS:
;   params - data structure with the same information contained in
;     ISEDFIT_PARAMFILE (over-rides ISEDFIT_PARAMFILE)
;   supergrid_paramfile - file describing the supergrid parameters 
;   thissfhgrid - if SUPERGRID_PARAMFILE contains multiple
;     supergrids then build this SUPERGRID (may be a vector)
;   sfhgrid_paramfile - parameter file name giving details on all the
;     available SFH grids (needed to initialize the output data
;     structure) 
;
;   outprefix - optionally write out files with a different prefix
;     from that specified in ISEDFIT_PARAMFILE (or PARAMS)
;   isedfit_dir - base pathname for iSEDfit files; the Monte Carlo
;     grids can be found in ISEDFIT_DIR/MONTEGRIDS, or in
;     MONTEGRIDS_DIR
;   use_redshift - use this redshift array instead of constructing the
;     redshift array from the parameters given in the
;     ISEDFIT_PARAMFILE parameter file; useful for when you have a
;     relatively sample of objects with well-determined redshifts
;     spanning a wide redshift range [NZZ]
;   index - use this optional input to fit a zero-indexed subset of
;     the full sample (default is to fit everything)
;
; KEYWORD PARAMETERS:
;   allages - allow solutions with ages that are older than the age of
;     the universe at the redshift of the object 
;   write_chi2grid - write out the full chi^2 grid across all the
;     models (these can be big files!)
;   silent - suppress messages to STDOUT
;   nowrite - do not write out any of the output files (generally not
;     recommended!) 
;   clobber - overwrite existing files of the same name (the default
;     is to check for existing files and if they exist to exit
;     gracefully)  
;
; OUTPUTS:
;   Binary FITS tables containing the fitting results are written
;   to ISEDFIT_DIR. 
;
; OPTIONAL OUTPUTS:
;   isedfit - output data structure containing all the results; see
;     the iSEDfit documentation for a detailed breakdown and
;     explanation of all the outputs
;   isedfit_post - output data structure containing the random draws
;     from the posterior distribution function, which can be used to
;     rebuild the posterior distributions of any of the output
;     parameters 
;
; COMMENTS:
;   WARNING: maggies, ivarmaggies, and zobj are copied into the output
;   structure and then the variables are deleted from memory.
;
;   Better documentation of the output data structures would be good. 
;
; MODIFICATION HISTORY:
;   J. Moustakas, 2011 Sep 01, UCSD - I began writing iSEDfit in 2005
;     while at the U of A, adding updates off-and-on through 2007;
;     however, the code has evolved so much that the old modification
;     history became obsolete!  Future changes to the officially
;     released code will be documented here.
;   jm13jan13siena - documentation rewritten and updated to reflect
;     many major changes
;
; Copyright (C) 2011, 2013, John Moustakas
; 
; This program is free software; you can redistribute it and/or modify 
; it under the terms of the GNU General Public License as published by 
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version. 
; 
; This program is distributed in the hope that it will be useful, but 
; WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; General Public License for more details. 
;-

function init_isedfit, ngal, nfilt, params=params, isedfit_post=isedfit_post
; ISEDFIT support routine - initialize the output structure 

    ndraw = params.ndraw ; number of random draws
    if (params.nmaxburst eq 0) then burstarray1 = -1.0 else $
      burstarray1 = fltarr(params.nmaxburst)-1.0

    isedfit1 = {$
      isedfit_id:      -1L,$    ; unique ID number
      zobj:           -1.0,$    ; redshift
;     zobj_err:       -1.0,$    ; redshift error
      maggies:     fltarr(nfilt),$ ; observed maggies
      ivarmaggies: fltarr(nfilt),$ ; corresponding inverse variance
      bestmaggies: fltarr(nfilt)}  ; best-fitting model photometry

; best-fit values (at the chi2 minimum); see BUILD_ISEDFIT_SFHGRID
    best = {$
      chunkindx:                 -1,$
      modelindx:                 -1,$
      delayed:       params.delayed,$ ; delayed tau model?
      bursttype:   params.bursttype,$ ; burst type
      chi2:                     1E6,$ ; chi2 minimum
      scale:                   -1.0,$ 
      scale_err:               -1.0,$ 

      mstar:                   -1.0,$ 
      age:                     -1.0,$
      sfrage:                  -1.0,$
      tau:                     -1.0,$
      Zmetal:                  -1.0,$
      AV:                       0.0,$ ; always initialize with zero to accommodate the dust-free models!
      mu:                       1.0,$ ; always default to 1.0!
      oiiihb:                  -1.0,$ 
      nlyc:                    -1.0,$ 
      sfr:                     -1.0,$ ; instantaneous
      sfr100:                  -1.0,$ ; 100 Myr timescale
      ewoii:                   -1.0,$ 
      ewoiiihb:                -1.0,$ 
      ewniiha:                 -1.0,$ 
      nburst:                     0,$
      trunctau:                -1.0,$ ; burst truncation time scale
      tburst:           burstarray1,$
      dtburst:          burstarray1,$ ; 
      fburst:           burstarray1}  ; burst mass fraction

;     chunkindx:        -1,$
;     modelindx:        -1,$
;     delayed:           0,$
;     bursttype:         0,$
;
;     tau:            -1.0,$
;     Zmetal:         -1.0,$
;     av:             -1.0,$
;     mu:             -1.0,$
;     nburst:            0,$
;     tautrunc:       -1.0,$ ; burst truncation time scale
;     tburst:    burstarray1,$
;     dtburst:   burstarray1,$
;     fburst:    burstarray1,$

;     b100:           -1.0}  ; averaged over the previous 100 Myr

; median quantities and PDF quantiles
    qmed = {$
;     mstar_avg:     -1.0,$
;     age_avg:      -1.0,$
;     sfr_avg:      -1.0,$ ; instantaneous
;     sfr100_avg:   -1.0,$ ; 100 Myr
;     b100_avg:     -1.0,$
;     tau_avg:      -1.0,$
;     Zmetal_avg:   -1.0,$
;     av_avg:       -1.0,$
;     mu_avg:       -1.0,$

      mstar_50:    -1.0,$
      age_50:      -1.0,$
      sfrage_50:   -1.0,$
      tau_50:      -1.0,$
      Zmetal_50:   -1.0,$
      av_50:       -1.0,$
      mu_50:       -1.0,$
      sfr_50:      -1.0,$ ; instantaneous
      sfr100_50:   -1.0,$ ; 100 Myr
      ewoii_50:    -1.0,$
      ewoiiihb_50: -1.0,$
      ewniiha_50:  -1.0,$

      mstar_err:    -1.0,$
      age_err:      -1.0,$
      sfrage_err:   -1.0,$
      tau_err:      -1.0,$
      Zmetal_err:   -1.0,$
      av_err:       -1.0,$
      mu_err:       -1.0,$
;     oiiihb_err:   -1.0,$
      sfr_err:      -1.0,$
      sfr100_err:   -1.0,$
      ewoii_err:    -1.0,$
      ewoiiihb_err: -1.0,$
      ewniiha_err:  -1.0}

;     mstar_eff_err:   -1.0,$
;     age_eff_err:    -1.0,$
;     sfr_eff_err:    -1.0,$
;     sfr100_eff_err: -1.0,$
;     b100_eff_err:   -1.0,$
;     tau_eff_err:    -1.0,$
;     Zmetal_eff_err: -1.0,$
;     av_eff_err:     -1.0,$
;     mu_eff_err:     -1.0}

    isedfit = struct_addtags(temporary(isedfit1),struct_addtags(best,qmed))
    isedfit = replicate(temporary(isedfit),ngal)

; initialize the posterior distribution structure
    isedfit_post = {$
      draws:     lonarr(ndraw)-1,$
      chi2:      fltarr(ndraw)-1,$
      scale:     fltarr(ndraw)-1,$
      scale_err: fltarr(ndraw)-1}
    isedfit_post = replicate(temporary(isedfit_post),ngal)
    
return, isedfit
end

pro isedfit, isedfit_paramfile, maggies, ivarmaggies, zobj, isedfit, $
  isedfit_post=isedfit_post, params=params, isedfit_dir=isedfit_dir, $
  thissfhgrid=thissfhgrid, outprefix=outprefix, index=index, $
  allages=allages, maxold=maxold, write_chi2grid=write_chi2grid, $
  silent=silent, nowrite=nowrite, clobber=clobber

    if n_elements(isedfit_paramfile) eq 0 and n_elements(params) eq 0 then begin
       doc_library, 'isedfit'
       return
    endif

; read the parameter file; parse to get the relevant path and
; filenames
    if (n_elements(params) eq 0) then params = $
      read_isedfit_paramfile(isedfit_paramfile,thissfhgrid=thissfhgrid)
    if (n_elements(isedfit_dir) eq 0) then isedfit_dir = './'

; error checking on the input photometry    
    ndim = size(maggies,/n_dim)
    dims = size(maggies,/dim)
    if (ndim eq 1) then ngal = 1 else ngal = dims[1]  ; number of galaxies
    nfilt = dims[0] ; number of filters

    nmaggies = n_elements(maggies)
    nivarmaggies = n_elements(ivarmaggies)
    nzobj = n_elements(zobj)
    
    if (nmaggies eq 0L) or (nivarmaggies eq 0L) or $
      (nzobj eq 0L) then begin
       doc_library, 'isedfit'
       return
    endif

    ndim = size(maggies,/n_dimension)
    if (ndim ne 2L) then begin ; reform into a 2D array
       maggies = reform(maggies,n_elements(maggies),1)
       ivarmaggies = reform(ivarmaggies,n_elements(maggies),1)
    endif

    if (n_elements(maggies) ne n_elements(ivarmaggies)) then begin
       splog, 'MAGGIES and IVARMAGGIES do not match'
       return
    endif
    if (nzobj ne ngal) then begin
       splog, 'MAGGIES and ZOBJ do not match'
       return
    endif
    if (total(finite(maggies) eq 0B) ne 0.0) or $
      (total(finite(ivarmaggies) eq 0B) ne 0.0) then begin
       splog, 'MAGGIES and IVARMAGGIES cannot have infinite values'
       return
    endif
    if (total(zobj le 0.0) ne 0.0) then begin
       splog, 'ZOBJ should all be positive'
       return
    endif

; treat each SFHgrid separately
    ngrid = n_elements(params)
    if ngrid gt 1 then begin
       for ii = 0, ngrid-1 do begin
          isedfit, isedfit_paramfile1, maggies, ivarmaggies, zobj, isedfit, $
            isedfit_post=isedfit_post, params=params[ii], isedfit_dir=isedfit_dir, $
            outprefix=outprefix, index=index, allages=allages, maxold=maxold, $
            write_chi2grid=write_chi2grid, silent=silent, nowrite=nowrite, $
            clobber=clobber
       endfor 
       return
    endif

    fp = isedfit_filepaths(params,isedfit_dir=isedfit_dir,ngalaxy=ngal,$
      ngalchunk=ngalchunk,outprefix=outprefix)

    isedfit_outfile = fp.isedfit_dir+fp.isedfit_outfile
    if file_test(isedfit_outfile+'.gz',/regular) and $
      (keyword_set(clobber) eq 0) and $
      (keyword_set(nowrite) eq 0) then begin
       splog, 'Output file '+isedfit_outfile+' exists; use /CLOBBER'
       return
    endif

; fit the requested subset of objects and return
    if (n_elements(index) ne 0L) then begin
       isedfit, isedfit_paramfile1, maggies[*,index], ivarmaggies[*,index], zobj[index], $
         isedfit1, isedfit_post=isedfit_post1, params=params, isedfit_dir=isedfit_dir, $
         outprefix=outprefix, allages=allages, write_chi2grid=write_chi2grid, $
         silent=silent, /nowrite, clobber=clobber
       isedfit = init_isedfit(ngal,nfilt,params=params,isedfit_post=isedfit_post)
       isedfit[index] = isedfit1
       isedfit_post[index] = isedfit_post1
       if (keyword_set(nowrite) eq 0) then begin
          im_mwrfits, isedfit, isedfit_outfile, /clobber
          im_mwrfits, isedfit_post, fp.isedfit_dir+fp.post_outfile, /clobber
       endif
       return
    endif

    if (keyword_set(silent) eq 0) then begin
       splog, 'SYNTHMODELS='+strtrim(params.synthmodels,2)+', '+$
         'REDCURVE='+strtrim(params.redcurve,2)+', IMF='+$
         strtrim(params.imf,2)+', '+'SFHGRID='+$
         string(params.sfhgrid,format='(I2.2)')
    endif

; filters and redshift grid
    filterlist = strtrim(params.filterlist,2)
    nfilt = n_elements(filterlist)

    redshift = params.redshift
    if (min(zobj)-min(redshift) lt -1E-3) or $
      (max(zobj)-max(redshift) gt 1E-3) then begin
       splog, 'Need to rebuild model grids using a wider redshift grid!'
       return
    endif

; if REDSHIFT is not monotonic then FINDEX(), below, can't be
; used to interpolate the model grids properly; this only really
; matters if USE_REDSHIFT is passed    
    if monotonic(redshift) eq 0 then begin
       splog, 'REDSHIFT should be a monotonically increasing or decreasing array!'
       return
    endif

; initialize the output structure(s)
    isedfit = init_isedfit(ngal,nfilt,params=params,isedfit_post=isedfit_post)
    isedfit.isedfit_id = lindgen(ngal)
    isedfit.maggies = maggies
    isedfit.ivarmaggies = ivarmaggies
    isedfit.zobj = zobj

; loop on each galaxy chunk
    t1 = systime(1)
    mem1 = memory(/current)
    for gchunk = 0L, ngalchunk-1 do begin
       g1 = gchunk*params.galchunksize
       g2 = ((gchunk*params.galchunksize+params.galchunksize)<ngal)-1
       gnthese = g2-g1+1
       gthese = lindgen(gnthese)+g1
; do not allow the galaxy to be older than the age of the universe at
; ZOBJ starting from a maximum formation redshift z=10 [Gyr]
       maxage = lf_z2t(zobj[gthese],omega0=params.omega0,$ ; [Gyr]
         omegal0=params.omegal)/params.h100
       zindx = findex(redshift,zobj[gthese]) ; used for interpolation
; loop on each "chunk" of output from ISEDFIT_MODELS
       nchunk = n_elements(fp.isedfit_models_chunkfiles)
       t0 = systime(1)
       mem0 = memory(/current)
       for ichunk = 0, nchunk-1 do begin
          print, format='("ISEDFIT: Chunk ",I0,"/",I0, A10,$)', ichunk+1, nchunk, string(13b)
          chunkfile = fp.modelspath+fp.isedfit_models_chunkfiles[ichunk]+'.gz'
;         if (keyword_set(silent) eq 0) then splog, 'Reading '+chunkfile
          modelchunk = mrdfits(chunkfile,1,/silent)
          nmodel = n_elements(modelchunk)
; compute chi2
          galaxychunk = isedfit_chi2(maggies[*,gthese],ivarmaggies[*,gthese],$
            modelchunk,maxage,zindx,gchunk=gchunk,ngalchunk=ngalchunk,ichunk=ichunk,$
            nchunk=nchunk,nminphot=params.nminphot,allages=allages,silent=silent,$
            maxold=maxold)
          if (ichunk eq 0) then begin
             galaxygrid = temporary(galaxychunk)
             modelgrid = temporary(modelchunk)
          endif else begin
             galaxygrid = [temporary(galaxygrid),temporary(galaxychunk)]
             modelgrid = [temporary(modelgrid),temporary(modelchunk)]
          endelse
       endfor ; close ModelChunk
; optionally write out the full chi2 grid 
       if keyword_set(write_chi2grid) then begin
          im_mwrfits, galaxygrid, clobber=clobber, fp.modelspath+fp.chi2grid_gchunkfiles[gchunk]
;         im_mwrfits, modelgrid, clobber=clobber, fp.modelspath+fp.modelgrid_gchunkfiles[gchunk]
       endif
; minimize chi2
       if (keyword_set(silent) eq 0) then splog, 'Building the posterior distributions...'
       temp_isedfit_post = isedfit_post[gthese]
       isedfit[gthese] = isedfit_posterior(isedfit[gthese],modelgrid=modelgrid,$
         galaxygrid=galaxygrid,params=params,isedfit_post=temp_isedfit_post)
       isedfit_post[gthese] = temporary(temp_isedfit_post) ; pass-by-value
       if (keyword_set(silent) eq 0) and (gchunk eq 0) then begin
          splog, 'First GalaxyChunk = '+string((systime(1)-t0)/60.0,format='(G0)')+$
            ' min, '+strtrim(string((memory(/high)-mem0)/1.07374D9,format='(F12.3)'),2)+' GB'
       endif 
    endfor ; close GalaxyChunk
    if (keyword_set(silent) eq 0) then begin
       splog, 'All GalaxyChunks = '+string((systime(1)-t1)/60.0,format='(G0)')+$
         ' min, '+strtrim(string((memory(/high)-mem1)/1.07374D9,format='(F12.3)'),2)+' GB'
    endif
    
; write out the final structure and the full posterior distributions
    if (keyword_set(nowrite) eq 0) then begin
       im_mwrfits, isedfit, isedfit_outfile, silent=silent, /clobber
       im_mwrfits, isedfit_post, fp.isedfit_dir+fp.post_outfile, silent=silent, /clobber
    endif

return
end
