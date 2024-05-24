function sm_spatiotemp_mapping(varargin)
global h


if ~isfield(h.inv_soln(h.current_inv_soln).soln.P,'img_org')     % saving original image from initial invSoln
    h.inv_soln(h.current_inv_soln).soln.P.img_org = h.inv_soln(h.current_inv_soln).soln.P.img;
end

% s=h.sim_data.cfg.study.act_samps;
% s_ctrl=h.sim_data.cfg.study.ctrl_samps;
s=h.cfg.study.bl_bmf.act_samps;
s_ctrl=h.cfg.study.bl_bmf.ctrl_samps;

ssp = nanmean(h.sim_data.sig_final(s,:,:),3);
ssp_ctrl = nanmean(h.sim_data.sig_final(s_ctrl,:,:),3);
norm_ssp = bsxfun(@rdivide, ssp, nanstd(ssp_ctrl,[],1));
norm_ssp = bsxfun(@minus, norm_ssp, nanmean(norm_ssp,1));   % baselining across act_int
vox_pos = h.inv_soln(h.current_inv_soln).leadfield.voxel_pos; % h.anatomy.leadfield.voxel_pos;
st_idx =[]; % spatiotemporal indices of found peak sources
search_thresh = str2num(h.edit_inv_peak_spread.String);  % search distance to find peaks
dist_thresh = str2num(h.edit_inv_dist_search_thresh.String);   % search dist around true sources to find hits

%% Spatiotemporal search for finding peak locations for single-source inv solns

switch h.inv_soln(h.current_inv_soln).Type
    case {'SPA' 'LCMV (FT)' 'sLORETA (FT)' 'dics (FT)' 'pcc (FT)' 'SAM (FT)' 'SIA' 'MIA' 'sMCMV' 'bRAPBeam' 'TrapMUSIC'}    % BRANE Lab beamformers
        swf = h.inv_soln(h.current_inv_soln).soln.wts' * squeeze(nanmean(h.sim_data.sens_final(s,h.anatomy.sens.good_sensors,:),3))';
        swf_ctrl = h.inv_soln(h.current_inv_soln).soln.wts' * squeeze(nanmean(h.sim_data.sens_final(s_ctrl,h.anatomy.sens.good_sensors,:),3))';
        if h.radio_normalize_swf.Value == 1; swf_base = abs(h.inv_soln(h.current_inv_soln).soln.wts' * squeeze(nanmean(h.sim_data.sens_final(h.sim_data.cfg.study.base_samps,h.anatomy.sens.good_sensors,:),3))'); end
    case {'eLORETA (FT)' }    % Field Trips inverse solutions
        swf=[]; swf_ctrl=[];
        for ox = 1:size(h.inv_soln(h.current_inv_soln).soln.wts,3)
            swf(:,ox,:)=squeeze(nanmean(h.sim_data.sens_final(s,h.anatomy.sens.good_sensors,:),3))*squeeze(h.inv_soln(h.current_inv_soln).soln.wts(:,:,ox));
            swf_ctrl(:,ox,:)=squeeze(nanmean(h.sim_data.sens_final(s,h.anatomy.sens.good_sensors,:),3))*squeeze(h.inv_soln(h.current_inv_soln).soln.wts(:,:,ox));
        end
        switch h.inv_soln(h.current_inv_soln).maxvectorori_Type
            case 'RMS'
                swf = squeeze(rms(swf,2))'; % taking RMS of waveforms across orientations
                swf_ctrl = squeeze(rms(swf_ctrl,2))'; % taking RMS of waveforms across orientations
            case 'Max'    % vector dipole orientation with maximum swf power between active and control interval
                swf = squeeze(max(swf,[],2))'; % taking RMS of waveforms across orientations
                swf_ctrl = squeeze(max(swf_ctrl,[],2))'; % taking RMS of waveforms across orientations
            case 'avg.pow'
                swf = squeeze(rms(swf,2))'; % taking RMS of waveforms across orientations
                swf_ctrl = squeeze(rms(swf_ctrl,2))'; % taking RMS of waveforms across orientations
        end
    case {'MNE (FT)' 'LCMV (BST)' 'MNE (BST)' 'sLORETA (BST)'}    % vector inverse solutions
        swf=[]; swf_ctrl=[];
        for ox = 1:size(h.inv_soln(h.current_inv_soln).soln.wts,3)
            swf(:,ox,:)=squeeze(nanmean(h.sim_data.sens_final(s,h.anatomy.sens.good_sensors,:),3))*squeeze(h.inv_soln(h.current_inv_soln).soln.wts(:,:,ox));
            swf_ctrl(:,ox,:)=squeeze(nanmean(h.sim_data.sens_final(s,h.anatomy.sens.good_sensors,:),3))*squeeze(h.inv_soln(h.current_inv_soln).soln.wts(:,:,ox));
        end
        
        switch h.inv_soln(h.current_inv_soln).maxvectorori_Type
            case 'RMS'
                swf = squeeze(rms(swf,2))'; % taking RMS of waveforms across orientations
                swf_ctrl = squeeze(rms(swf_ctrl,2))'; % taking RMS of waveforms across orientations
            case 'Max'    % vector dipole orientation with maximum swf power between active and control interval
                swf = squeeze(max(swf,[],2))'; % taking RMS of waveforms across orientations
                swf_ctrl = squeeze(max(swf_ctrl,[],2))'; % taking RMS of waveforms across orientations
            case 'avg.pow'
                swf = squeeze(h.inv_soln(h.current_inv_soln).soln.avg.pow(:,s)); % taking RMS of waveforms across orientations
                swf_ctrl = squeeze(h.inv_soln(h.current_inv_soln).soln.avg.pow(:,s)); % taking RMS of waveforms across orientations
        end
        
end

%% find all local maxima in abs(swf) for each time sample
p_idx = [];
fprintf('Running Spatiotemporal mapping between %.f - %.f ms\n',h.sim_data.cfg.study.lat_sim(s([1 end]))*1000);
for ss=1:length(s)
    fprintf('%.f ',h.sim_data.cfg.study.lat_sim(s(ss))*1000)
    voxel_vals=[vox_pos, abs(swf(:,ss))];
    null_dist = sort(reshape(abs(swf_ctrl),[numel(swf_ctrl), 1])); thresh_val = null_dist(ceil(length(null_dist)*.95)); % nanmedian(abs(swf(:,ss)));  % finding median value to speed up;
    [peak_voxel,pidx]=BRANELab_find_peak_voxel_thresh(voxel_vals,thresh_val,search_thresh);   % searches for all peaks
    p_idx = unique([p_idx; pidx]);
end
fprintf('\n');

% find spatiotemporal peaks with 4 cm radius of true location
%         dist_thresh = [40 40 40]; % X, Y, Z mm distance between found source locations and true source locations
st_idx=[]; found_idx = [];
for v=1:size(h.sim_data.cfg.source.vx_locs,1)
    found_idx = find ( abs(vox_pos(p_idx,1)-h.sim_data.cfg.source.vx_locs(v,1))<=dist_thresh & ...
        abs(vox_pos(p_idx,2)-h.sim_data.cfg.source.vx_locs(v,2))<=dist_thresh & ...
        abs(vox_pos(p_idx,3)-h.sim_data.cfg.source.vx_locs(v,3))<=dist_thresh );
    if ~isempty(found_idx)  % find best match with norm_swf and true_source waveform using correlation
        
        %% spatial error
        spatial_rmse =   sqrt( ( (vox_pos(p_idx(found_idx),1)-h.sim_data.cfg.source.vx_locs(v,1)).^2 + ...
            (vox_pos(p_idx(found_idx),2)-h.sim_data.cfg.source.vx_locs(v,2)).^2 + ...
            (vox_pos(p_idx(found_idx),3)-h.sim_data.cfg.source.vx_locs(v,3)).^2 ) )' ;
        
        %% temporal error - residual variance just like for dipole fitting
        norm_swf = bsxfun(@rdivide,swf(p_idx(found_idx),:), nanstd( swf_ctrl(p_idx(found_idx),:),[],2 ))';
        norm_swf = bsxfun(@minus, norm_swf, nanmean(norm_swf,1));   % baselining across act_int
        % % rmse
        % temporal_rmse = sqrt(nanmean((norm_swf-norm_ssp(:,v)).^2));
        % temporal_rmse_flip = sqrt(nanmean((-norm_swf-norm_ssp(:,v)).^2));   % flipping temporal swf to see if error is smaller
        
        % % residual variance as a fraction - lower is better fit
        temporal_rmse = sum( (norm_swf-norm_ssp(:,v)).^2) ./ sum(norm_swf.^2);     % same as field Trip's Calculation
        temporal_rmse_flip = sum( (-norm_swf-norm_ssp(:,v)).^2) ./ sum(norm_swf.^2);     % same as field Trip's Calculation
        
        temporal_rmse = min([temporal_rmse; temporal_rmse_flip]); % finding smallest rmse between nonflipped and flipped waveforms
        
        %                 spatiotemp_error = spatial_rmse .* temporal_rmse; % spatiotemporal error = spatial_rmse * temporal_rmse;
        
        spatiotemp_error = (spatial_rmse/10) .* temporal_rmse; % 1/10 wieghting to spatial_rmse because sometimes closer source does not have better matching waveform
        
        
        [q,w] = min(spatiotemp_error);
        widx(v) = w;
        st_idx(v) = p_idx(found_idx(w));
        
        if st_idx(v)==0 % if no location found then find nearest within entire brain space
            st_idx(v) = find_nearest_voxel(h.sim_data.cfg.source.vx_locs(v,:),vox_pos(p_idx,:));
        end
        
    else        % if no locations found within dip_thresh for any sources then find nearest within entire brain space
        for v = 1:3
            st_idx(v) = find_nearest_voxel(h.sim_data.cfg.source.vx_locs(v,:),vox_pos(p_idx,:));
        end
    end
end

diff_idx = setdiff(p_idx,st_idx);
v_idx = [st_idx diff_idx'];
%         v_idx = st_idx;     % only peak sources
%         img = rms(swf')';
img = max(abs(swf'))';
img = zeros(size(swf,1),1);
img(v_idx) = max(abs(swf(v_idx,:)'))';
%         img(img<h.slider_3D_image_thresh.Value) = 0;

%                 figure(99); clf; hold on; plot(swf','k'); plot(swf(st_idx,:)','r');


h.current_3D_peak_voxels = [vox_pos(v_idx,:), img(v_idx), v_idx']; h.current_3D_peak_idx = v_idx;
h.inv_soln(h.current_inv_soln).peak_idx = v_idx;
h.inv_soln(h.current_inv_soln).peak_voxels = h.current_3D_peak_voxels;
h.inv_soln(h.current_inv_soln).soln.P.img = img;    % overwriting with combined spatiotemporal maps using rms(swf)

h.inv_soln(h.current_inv_soln).soln.plot_min_max = [min(img) max(img)];



