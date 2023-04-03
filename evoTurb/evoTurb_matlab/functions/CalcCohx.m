%% CalcCohx
% function: calculate the longitudinal coherence

%% Usage
% [Cohx,ConfigParameters] = CalcCohx(ConfigParameters)

%% Inputs
%  ConfigParameters: -struct, configuration parameters 

%% Outputs
%  ConfigParameters: configuration parameters, -struct 
%  Cohx: longitudinal coherence
%         - 3D array, with size of [Nplanes,Nplanes,number of freq] 

%% References
% 1.'Exp-UserDefined' uses the wind evolution model (Eq.4) and
%   'Exp-Simley' uses the wind evolution model (Eq.7) and in
        % Simley, E., & Pao, L. Y. (2015). 
        % A longitudinal spatial coherence model for wind evolution based on large-eddy simulation. 
        % In 2015 American Control Conference (ACC) (pp. 3708–3714). IEEE. 
        % https://doi.org/10.1109/ACC.2015.7171906
%    This model is acquired from LES simulations.

% 2.'Kristensen' uses the wind evolution model (Eq.20) and G-function (Eq.29) in
        % Kristensen, L. (1979). 
        % On longitudinal spectral coherence. 
        % Boundary-Layer Meteorology, 16(2), 145–153. 
        % https://doi.org/10.1007/BF02350508
%    This model is based on physical deduction.
    
% 3.'Exp-GPR' uses the wind evolution model (Eq.6) and 
%    the GPR models case 15 for a and case 17 for b (Table5) in
        % Chen, Y., Schlipf, D., & Cheng, P. W. (2021). 
        % Parameterization of wind evolution using lidar. 
        % Wind Energy Science, 6(1), 61–91. 
        % https://doi.org/10.5194/wes-6-61-2021
%    The GPR models are trained with measurement data from an onshore flat site.
%    Due to the limitation of the training data, it is not recommended to 
%    use the GPR models for the cases where the separations between the unfrozen planes exceed 109 m.

%% Created on 03.06.2021 
% Yiyin Chen    (c) University of Stuttgart 
% Feng Guo      (c) Flensburg University of Applied Sciences

%% Modified:
%

%% function
function [Cohx,ConfigParameters] = CalcCohx(ConfigParameters)

% spatial distance x
r_x = reshape(pdist2(ConfigParameters.Xpos(:),ConfigParameters.Xpos(:)),[],1);

if ~strcmp(ConfigParameters.EvoModel,'Exp-UserDefined')
    
    % calculate wind statistics to determine wind evolution model parameters

    if strcmp(ConfigParameters.TurbModel,'Kaimal')
 
        % Check Turbulence Class
        % Iref: expected value of the turbulence intensity at 15 m/s. (IEC61400-1:2005 p.22)
        %       Note that IRef is defined as the mean value in this edition of the standard rather than as a representative value.        
        if strcmp(ConfigParameters.TurbClass, 'A+')
            Iref=0.18;
        elseif strcmp(ConfigParameters.TurbClass,'A')
            Iref=0.16; 
        elseif strcmp(ConfigParameters.TurbClass,'B')
            Iref=0.14; 
        elseif strcmp(ConfigParameters.TurbClass,'C')
            Iref=0.12;
        else
            error('Wrong turbulence class. Please define IEC turbulence Class as A+, A, B, or C.')
        end
        
        % sigma_u: the representative value of the turbulence standard deviation, 
        %          shall be given by the 90% quantile for the given hub height wind speed (IEC61400-1:2005 p.24)
        sigma_u = Iref.*(0.75.*ConfigParameters.Uref+5.6); 
        sigma_v = sigma_u*0.8;
        sigma_w = sigma_u*0.5;
        sigma_total = sqrt(sigma_u^2+sigma_v^2+sigma_w^2);

        % Lambda = longitudinal turbulence scale parameter
        if ConfigParameters.Href > 60
            Lambda = 42;
        else
            Lambda = 0.7*ConfigParameters.Href;
        end

        % Integral length scale
        Lu = 8.1*Lambda;
        
        % save the parameters
        ConfigParameters.sigma_u = sigma_u;
        ConfigParameters.sigma_v = sigma_v;
        ConfigParameters.sigma_w = sigma_w;
        ConfigParameters.L_u = Lu;
    
    elseif strcmp(ConfigParameters.TurbModel,'Mann')
        
        sigma_total = sqrt(ConfigParameters.sigma_u^2+ConfigParameters.sigma_v^2+ConfigParameters.sigma_w^2);
        Lu = ConfigParameters.L_u;
        
    end
    
end

% coherence x
switch ConfigParameters.EvoModel
    case 'Exp-UserDefined'
        Cohx_squared = exp(-ConfigParameters.evo_a.*sqrt((ConfigParameters.f.*r_x./ConfigParameters.Uref).^2+...
            (ConfigParameters.evo_b.*r_x).^2));
    
    case 'Exp-Simley'
        ConfigParameters.evo_a = 8.4*sigma_total/ConfigParameters.Uref+0.05;
        ConfigParameters.evo_b = 0.25.*Lu^(-1.24);
        Cohx_squared = exp(-ConfigParameters.evo_a.*sqrt((ConfigParameters.f.*r_x./ConfigParameters.Uref).^2+...
            (ConfigParameters.evo_b.*r_x).^2));
    
    case 'Kristensen'
        xi = ConfigParameters.f.*Lu./ConfigParameters.Uref;
        alpha = sigma_total/ConfigParameters.Uref.*r_x./Lu;
        G = 33.^(-2/3).*(33.*xi).^2.*(33.*xi+3/11).^0.5./(33.*xi+1).^(11/6);
        m = 2.*(alpha<=1)+1.*(alpha>1);
        Cohx_squared = exp(-2.*alpha.*G).*(1-exp(-1./(2.*alpha.^m.*xi.^2))).^2;
        
    case 'Exp-GPR'
        load ExpGPR.mat
        predictor_a = struct2table(struct('V_long_mean',ConfigParameters.Uref,...
            'V_vert_std',ConfigParameters.sigma_w,'DirError',0));
        predictor_b = struct2table(struct('V_long_mean',ConfigParameters.Uref*ones(size(r_x)),...
            'V_long_TI_U',ConfigParameters.sigma_u/ConfigParameters.Uref*ones(size(r_x)),...
            'V_long_skew',zeros(size(r_x)),'V_long_kurt',zeros(size(r_x)),...
            'V_lat_skew',zeros(size(r_x)),'V_vert_skew',zeros(size(r_x)),...
            'vlos_d',r_x));
        ConfigParameters.evo_a = predict(cgprMdl_a,predictor_a);
        ConfigParameters.evo_b = predict(cgprMdl_b,predictor_b);
        ConfigParameters.evo_b(predictor_b.vlos_d==0)=0; 
        Cohx_squared = exp(-sqrt(ConfigParameters.evo_a.^2.*(ConfigParameters.f.*r_x./ConfigParameters.Uref).^2+...
            ConfigParameters.evo_b.^2));
     
end

Cohx = reshape(sqrt(Cohx_squared),[ConfigParameters.Nplanes,ConfigParameters.Nplanes,length(ConfigParameters.f)]);

