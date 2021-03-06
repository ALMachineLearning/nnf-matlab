classdef NNdb < handle
    % NNDB represents database for NNFramwork.
    % IMPL_NOTES: Pass by reference class.
    %
    % i.e
    % Database with same no. of images per class, with build class idx
    % nndb = NNdb('any_name', imdb, 8, true)
    %
    % Database with varying no. of images per class, with build class idx
    % nndb = NNdb('any_name', imdb, [4 3 3 1], true)
    %
    % Database with given class labels
    % nndb = NNdb('any_name', imdb, [4 3], false, [1 1 1 1 2 2 2])
    
    % Copyright 2015-2016 Nadith Pathirage, Curtin University (chathurdara@gmail.com).
    
	properties (SetAccess = public) 
        db;             % (M) Actual Database   
        format;         % (s) Current Format of The Database
        
        h;              % (s) Height (Y dimension)
        w;              % (s) Width (X dimension)
        ch;             % (s) Channel Count
        n;              % (s) Sample Count
        
        n_per_class;    % (v) No of images per class (classes may have different no. of images)  
        cls_st;         % (v) Class Start Index  (internal use, can be used publicly)
        build_cls_lbl   % (s) Build the class labels or not.
        cls_lbl;        % (v) Class Index Array
        cls_n;          % (s) Class Count
  	end
                
    properties (SetAccess = public, Dependent)
        db_convo_th;    % db compatible for convolutional networks.
        db_convo_tf;    % db compatible for convolutional networks.        
        db_scipy;       % db compatible for scipy library.
        features_scipy; % 2D feature matrix (double) compatible for scipy library.
        db_matlab;      % db compatible for matlab.
        features;       % 2D feature matrix (double) compatible for matlab.
        im_ch_axis;     % Image channel index for an image.
    end

    methods (Access = public) 
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Public Interface
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%       
        function self = NNdb(name, db, n_per_class, build_cls_lbl, cls_lbl, format) 
            % Constructs a nndb object.
            %
            % Parameters
            % ----------
            % db : 4D tensor -uint8
            %     Data tensor that contains images.
            % 
            % n_per_class : vector -uint16 or scalar, optional
            %     No. images per each class. (Default value = []).
            % 
            % build_cls_lbl : bool, optional
            %     Build the class indices or not. (Default value = false).
            % 
            % cls_lbl : vector -uint16 or scalar, optional
            %     Class index array. (Default value = []).
            % 
            % format : nnf.db.Format, optinal
            %     Format of the database. (Default value = 1, start from 1).
            %             

            disp(['Costructor::NNdb ' name]);
            
            % Imports
            import nnf.db.Format; 
                        
            % Set defaults for arguments
            if (nargin < 3), n_per_class = []; end
            if (nargin < 4), build_cls_lbl = false; end
            if (nargin < 5), cls_lbl = []; end
            if (nargin < 6), format = Format.H_W_CH_N; end     
            
            % Error handling for arguments
            if (isscalar(cls_lbl))
                error('ARG_ERR: cls_lbl: vector indicating class for each sample');
            end
            
            if (isempty(db))
                self.db = []; 
                self.n_per_class = [];
                self.build_cls_lbl = build_cls_lbl;
                self.cls_lbl = cls_lbl;
                self.format = format;
                self.h = 0; self.w = 1; self.ch = 1; self.n = 0;                
                self.cls_st = [];                
                self.cls_n = 0;
                return
            end
                        
            % Set values for instance variables
            self.set_db(db, n_per_class, build_cls_lbl, cls_lbl, format);
        end
      
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
        function nndb = merge(self, nndb)
            % Imports
            import nnf.db.NNdb;
            import nnf.db.Format;
            
            assert(self.h == nndb.h && self.w == nndb.w && self.ch == nndb.ch);
            assert(self.cls_n == nndb.cls_n);
            assert(self.cls_n == nndb.cls_n)
            assert(strcmp(class(self.db), class(nndb.db)))
            assert(self.format == nndb.format)
        
            if (self.format == Format.H_W_CH_N)
                db = cast(zeros(self.h, self.w, self.ch, self.n + nndb.n), class(self.db));
            elseif (self.format == Format.H_N)
                db = cast(zeros(self.h * self.w * self.ch, self.n + nndb.n), class(self.db));
            elseif (self.format == Format.N_H_W_CH)
                db = cast(zeros(self.n + nndb.n, self.h, self.w, self.ch), class(self.db));
            elseif (self.format == Format.N_H)
                db = cast(zeros(self.n + nndb.n, self.h * self.w * self.ch), class(self.db));
            end
            
            cls_lbl = uint16(zeros(1, self.n + nndb.n));
            en = 0;
            for i=1:self.cls_n
                % Fetch data from db1
                cls_st = self.cls_st(i);
                cls_end = cls_st + uint32(self.n_per_class(i)) - uint32(1);
                
                st = en + 1;
                en = st + self.n_per_class(i) - 1;
                cls_lbl(st:en) = i .* uint16(ones(1, self.n_per_class(i)));
                
                if (self.format == Format.H_W_CH_N)
                    db(:, :, :, st:en) = self.db(:, :, :, cls_st:cls_end);
                elseif (self.format == Format.H_N)
                    db(:, st:en) = self.db(:, cls_st:cls_end);
                elseif (self.format == Format.N_H_W_CH)
                    db(st:en, :, :, :) = self.db(cls_st:cls_end, :, :, :);
                elseif (self.format == Format.N_H)
                    db(st:en, :) = self.db(cls_st:cls_end, :);
                end            
                
                % Fetch data from db2
                cls_st = nndb.cls_st(i);
                cls_end = cls_st + uint32(nndb.n_per_class(i)) - uint32(1);
                
                st = en + 1;
                en = st + nndb.n_per_class(i) - 1;
                cls_lbl(st:en) = i .* uint16(ones(1, nndb.n_per_class(i)));
                
                if (self.format == Format.H_W_CH_N)
                    db(:, :, :, st:en) = nndb.db(:, :, :, cls_st:cls_end);
                elseif (self.format == Format.H_N)
                    db(:, st:en) = nndb.db(:, cls_st:cls_end);
                elseif (self.format == Format.N_H_W_CH)
                    db(st:en, :, :, :) = nndb.db(cls_st:cls_end, :, :, :);
                elseif (self.format == Format.N_H)
                    db(st:en, :) = nndb.db(cls_st:cls_end, :);
                end
            end
                        
            nndb = NNdb('merged', db, [], false, cls_lbl, self.format);            
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function update_attr(self, is_new_class, sample_n)
            % UPDATE_NNDB_ATTR: update nndb attributes. Used when building the nndb dynamically.
            %
            
            % Initialize db related fields
            self.init_db_fields__();
                
            % Set class start, and class counts of nndb
            if (is_new_class) 
                % Set class start(s) of nndb, dynamic expansion
                cls_st = self.n; % current sample count
                if (isempty(self.cls_st)); self.cls_st = uint32([]); end
                self.cls_st = cat(2, self.cls_st, uint32([cls_st]));

                % Set class count
                self.cls_n = self.cls_n + 1;

                % Set n_per_class(s) of nndb, dynamic expansion
                n_per_class = 0;
                if (isempty(self.n_per_class)); self.n_per_class = uint16([]); end
                self.n_per_class = cat(2, self.n_per_class, uint16([n_per_class]));
            end    

            % Increment the n_per_class current class
            self.n_per_class(end) = self.n_per_class(end) + 1;

            % Set class label of nndb, dynamic expansion
            cls_lbl = self.cls_n;
            if (isempty(self.cls_lbl)); self.cls_lbl = uint16([]); end
            self.cls_lbl = cat(2, self.cls_lbl, uint16([cls_lbl]));
        end       
            
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function data = get_data_at(self, si) 
            % GET_DATA_AT: gets data from database at i.
            %
            % Parameters
            % ----------
            % si : int
            %     Sample index.
            %             
            
            % Imports
            import nnf.db.Format;
            
            % Error handling for arguments
            assert(si <= self.n);            
                        
            % Get data according to the format
            if (self.format == Format.H_W_CH_N)
                data = self.db(:, :, :, si);
            elseif (self.format == Format.H_N)
                data = self.db(:, si);
            elseif (self.format == Format.N_H_W_CH)
                data = self.db(si, :, :, :);
            elseif (self.format == Format.N_H)
                data = self.db(si, :);
            end
        end
        
       	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function add_data(self, data) 
            % ADD_DATA: adds data into the database.
            %
            % Parameters
            % ----------
            % data : `array_like`
            %     Data to be added.
            %
            % Notes
            % -----
            % Dynamic allocation for the data tensor.
            % 
            
            % Imports
            import nnf.db.Format;

            % Add data according to the format (dynamic allocation)
            if (self.format == Format.H_W_CH_N)                
                if (isempty(self.db))
                    self.db = data;
                else
                    self.db = cat(4, self.db, data);
                end

            elseif (self.format == Format.H_N)
                if (isempty(self.db))
                    self.db = data;
                else
                    self.db = cat(2, self.db, data);
                end               

            elseif (self.format == Format.N_H_W_CH)
                if (isempty(self.db))
                    self.db = data;
                else
                    self.db = cat(1, self.db, data);
                end 

            elseif (self.format == Format.N_H)
                if (isempty(self.db))
                    self.db = data;
                else
                    self.db = cat(1, self.db, data);
                end 
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function features = get_features(self, cls_lbl) 
            % 2D Feature Matrix (double)
            %
            % Parameters
            % ----------
            % cls_lbl : uint16, optional
            %     featres for class denoted by cls_lbl.
            %
            
            features = double(reshape(self.db, self.h * self.w * self.ch, self.n));
            
            % Select class
            if (nargin >= 2)
                 features = features(:, self.cls_lbl == cls_lbl);
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%      
        function set_db(self, db, n_per_class, build_cls_lbl, cls_lbl, format) 
            % SET_DB: sets database and update relevant instance variables.
            % i.e (db, format, cls_lbl, cls_n, etc)
            %
            % Parameters
            % ----------
            % db : 4D tensor -uint8
            %     Data tensor that contains images.
            % 
            % n_per_class : vector -uint16 or scalar, optional
            %     No. images per each class. (Default value = []).
            %     If (n_per_class=[] and cls_lbl=[]) then n_per_class = total image count
            % 
            % build_cls_lbl : bool, optional
            %     Build the class indices or not. (Default value = false).
            % 
            % cls_lbl : vector -uint16 or scalar, optional
            %     Class index array. (Default value = []).
            % 
            % format : nnf.db.Format, optinal
            %     Format of the database. (Default value = 1, start from 1).
            %
            
            % Imports
            import nnf.db.Format; 

            % Error handling for arguments
            if (isempty(db))
                error('ARG_ERR: n_per_class: undefined');
            end                      
            if (isempty(format))
                error('ARG_ERR: format: undefined');
            end            
            if (~isempty(cls_lbl) && build_cls_lbl)
                warning('ARG_CONFLICT: cls_lbl, build_cls_lbl');
            end
            
            % Set defaults for n_per_class
            if (isempty(n_per_class) && isempty(cls_lbl))
                if (format == Format.H_W_CH_N)
                    [~, ~, ~, n_per_class] = size(db);
                elseif (format == Format.H_N)
                    [~, n_per_class] = size(db);
                elseif (format == Format.N_H_W_CH)
                    [n_per_class, ~, ~, ~] = size(db);
                elseif (format == Format.N_H)
                    [n_per_class, ~] = size(db);
                end
                
            elseif (isempty(n_per_class))
                % Build n_per_class from cls_lbl
                [n_per_class, ~] = hist(cls_lbl,unique(double(cls_lbl)));
            end
            
        	% Set defaults for instance variables
            self.db = []; self.format = [];
            self.h = 0; self.w = 1; self.ch = 1; self.n = 0;
            self.n_per_class = [];
            self.cls_st = [];
            self.cls_lbl = [];
            self.cls_n = 0;
            
            % Set values for instance variables
            self.db     = db;
            self.format = format;
            self.build_cls_lbl = build_cls_lbl;
            
            % Set h, w, ch, np according to the format    
            if (format == Format.H_W_CH_N)
                [self.h, self.w, self.ch, self.n] = size(self.db);
            elseif (format == Format.H_N)
                [self.h, self.n] = size(self.db);
            elseif (format == Format.N_H_W_CH)
                [ self.n, self.h, self.w, self.ch] = size(self.db);
            elseif (format == Format.N_H)
                [self.n, self.h] = size(self.db);
            end
                   
            % Set class count, n_per_class, class start index
            if (isscalar(n_per_class))
                if (mod(self.n, n_per_class) > 0)
                    error('Total image count (n) is not divisable by image per class (n_per_class)')
                end            
                self.cls_n = self.n / n_per_class;
                self.n_per_class =  uint16(repmat(n_per_class, 1, self.cls_n));
                tmp = uint32(self.n_per_class .* uint16(1:self.cls_n) + uint16(ones(1, self.cls_n)));
                self.cls_st = [1 tmp(1:end-1)];
            else
                self.cls_n = numel(n_per_class);
                self.n_per_class =  uint16(n_per_class);
                
                if (self.cls_n > 0)
                    self.cls_st = uint32(zeros(1, numel(n_per_class)));
                    self.cls_st(1) = 1;
                    
                    if (self.cls_n > 1)                    
                        st = n_per_class(1) + 1;
                        for i=2:self.cls_n
                            self.cls_st(i) = st;
                            st = st + n_per_class(i);                    
                        end
                    end
                end  
            end
            
            % Set class labels
            self.cls_lbl = cls_lbl;  
                  
            % Build uniform cls labels if cls_lbl is not given  
            if (build_cls_lbl && isempty(cls_lbl))
                    self.build_sorted_cls_lbl();
            end             
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function build_sorted_cls_lbl(self) 
            % BUILD_sorted_CLS_LBL: Builds a sorted class indicies/labels  for samples
            
            n_per_class = self.n_per_class;            
                        
            % Each image should belong to a class            
            cls_lbl = uint16(zeros(1, self.n));    
            st = 1;
            for i = 1:self.cls_n
                cls_lbl(st: st + n_per_class(i) - 1) = uint16(ones(1, n_per_class(i)) * i);                
                st = st + n_per_class(i);
            end
            
            % Set values for instance variables
            self.cls_lbl = cls_lbl;           
            
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function new_nndb = clone(self, name) 
            % CLONE: Creates a copy of this NNdb object
            %
            % Imports 
            import nnf.db.NNdb;
            
            new_nndb = NNdb(name, self.db, self.n_per_class, self.build_cls_lbl, self.cls_lbl, self.format);
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function show(self, cls_n, n_per_class, scale, offset) 
            % SHOW: Visualizes the db in a image grid.
            %
            % Parameters
            % ----------
            % cls_n : int, optional
            %     No. of classes.
            % 
            % n_per_class : int, optional
            %     Images per class.
            % 
            % scale : int, optional
            %     Scaling factor. (Default value = [])
            % 
            % offset : int, optional
            %     Image index offset to the dataset. (Default value = 1)
            %
            % Examples
            % --------
            % Show first 5 subjects with 8 images per subject. (offset = 1)
            % .Show(5, 8)
            %
            % Show next 5 subjects with 8 images per subject, starting at (5*8 + 1)th image.
            % .Show(5, 8, [], 5*8 + 1)
            %
            
            % Imports
            import nnf.utl.immap;
            
            if (nargin >= 5)
                immap(self.db_matlab, cls_n, n_per_class, scale, offset);
            elseif (nargin >= 4)
                immap(self.db_matlab, cls_n, n_per_class, scale);
            elseif (nargin >= 3)
                immap(self.db_matlab, cls_n, n_per_class);
            elseif (nargin >= 2)
                immap(self.db_matlab, cls_n, 1);
            elseif (nargin >= 1)
                immap(self.db_matlab, 1, 1);
            end            
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function save(self, filepath) 
            % Save images to a matfile. 
            % 
            % Parameters
            % ----------
            % filepath : string
            %     Path to the file.
            %
            
            imdb_obj.db = self.db_matlab;
            imdb_obj.class = self.cls_lbl;
            imdb_obj.im_per_class = self.n_per_class;
            save(filepath, 'imdb_obj', '-v7.3');
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function save_compressed(self, filepath) 
            % Save images to a matfile. 
            % 
            % Parameters
            % ----------
            % filepath : string
            %     Path to the file.
            %
            
            imdb_obj.db = self.db_matlab;
            
            unq_n_per_class = unique(self.n_per_class);
            if isscalar(unq_n_per_class)
                imdb_obj.im_per_class = unq_n_per_class;
                imdb_obj.class = [];
            else            
                imdb_obj.im_per_class = self.n_per_class;
                imdb_obj.class = self.cls_lbl;
            end
            
            save(filepath, 'imdb_obj', '-v7.3');
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function save_to_dir(self, filepath, create_cls_dir) 
            % Save images to a directory. 
            % 
            % Parameters
            % ----------
            % path : string
            %     Path to directory.
            % 
            % create_cls_dir : bool, optional
            %     Create directories for individual classes. (Default value = True).
            %
            
            % Set defaults
            if (nargin < 3); create_cls_dir = true; end
            
            % Make a new directory to save images
            if (~isempty(filepath) && exist(filepath, 'dir') == 0)
                mkdir(filepath);
            end
            
            img_i = 1;
            for cls_i=1:self.cls_n

                cls_name = num2str(cls_i); 
                if (create_cls_dir && exist(fullfile(filepath, cls_name), 'dir') == 0)
                    mkdir(fullfile(filepath, cls_name));
                end

                for cls_img_i=1:self.n_per_class(cls_i)
                    if (create_cls_dir)
                        img_name = num2str(cls_img_i);
                        imwrite(self.get_data_at(img_i), fullfile(filepath, cls_name, [img_name '.jpg']), 'jpg');
                    else                
                        img_name = [cls_name '_' num2str(cls_img_i)];
                        imwrite(self.get_data_at(img_i), fullfile(filepath, [img_name '.jpg']), 'jpg');
                    end
                    
                    img_i = img_i + 1;
                end
            end
        end
            
       	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function plot(self, n, offset) 
            % PLOT: plots the features.
            %   2D and 3D plots are currently supported.
            %
            % Parameters
            % ----------
            % n : int, optional
            %     No. of samples to visualize. (Default value = self.n)
            % 
            % offset : int, optional
            %     Sample index offset. (Default value = 1)
            %
            %
            % Examples
            % --------
            % plot 5 samples. (offset = 1)
            % .plot(5, 8)
            %
            % plot 5 samples starting from 10th sample
            % .plot(5, 10)
            %                        
            
            % Set defaults for arguments
            if (nargin < 2), n = self.n; end
            if (nargin < 3), offset = 1; end
            
            X = self.features;
            fsize = size(X, 1);
            
            % Error handling
            if (fsize > 3)
                error(['self.h = ' num2str(self.h) ', must be 2 for (2D) or 3 for (3D) plots']);
            end
            
            % Draw with colors if labels are avaiable
            if (~isempty(self.cls_lbl))
                for i=1:self.cls_n
                    
                    % Set st and en for class i
                    st = self.cls_st(i);
                    en = st + uint32(self.n_per_class(i)) - 1;
                    
                    % Break
                    if (st > offset + n - 1); break; end
                    
                    % Draw samples starting at offset
                    if (en > offset)
                        st = offset; 
                    else
                        continue;
                    end
                    
                    % Draw only n samples
                    if (en > offset + n - 1); en = offset + n - 1; end
                    
                    % Draw 2D or 3D plot
                    if (fsize == 2)
                        c = self.cls_lbl(st:en);
                        s = scatter(X(1, st:en), X(2, st:en), 25, c, 'filled', 'MarkerEdgeColor', 'k');
                        s.LineWidth = 0.1;
                        
                    elseif (fsize == 3)
                        c = self.cls_lbl(st:en);
                        s = scatter3(X(1, st:en), X(2, st:en), X(3, st:en), 25, c, ...
                                                            'filled', 'MarkerEdgeColor', 'k');
                        s.LineWidth = 0.1;                        
                    end
                end
                
                hold off;
            end
            
        end
                
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function rgb2colors(self, normalized, to15, to22) 
            % RGB2COLORS: Convert RGB db to 15 or 22 color components.
            %
            
            % Set defaults for arguments
            if (nargin < 3), to15 = true; end
            if (nargin < 4), to22 = false; end
            
            % Error handling for arguments
            if (to15 && to22)
                warning('ARG_CONFLICT: to15, to22');
            end
            
            if (~to15 && ~to22)
                error('ARG_ERR:to15, to22: both are false');
            end
            
            %%% TRANFORMATION FUNCTIONS
            ColorTC = cell(1, 1);            
            ColorTC{1}=[1,0,0;0,1,0;0,0,1]; % RGB
            ColorTC{2}=[0.607,0.299,0.000;0.174,0.587,0.066;0.201,0.114,1.117]; %XYZ
            ColorTC{3}=[0.2900,0.5957,0.2115;0.5870,-0.2744,-0.5226;0.1140,-0.3213,0.3111]; %YIQ
            ColorTC{4}=[1/3,1/2,-1/2;1/3,0,1;1/3,-1/2,-1/2]; %III
            %YCbCr=[(0.2126*219)/255,(0.2126*224)/(1.8556*255),(0.5*224)/255;(0.7152*219)/255, ...
            %       (0.7152*224)/((1.8556*255)),-((0.7152*224)/(1.5748*255));..
            %       (0.0722*219)/255,(0.5*224)/255,-((0.0722*224)/(1.5748*255))];
            YCbCr_T   = (1/255) * [65.481 -37.797 112; 128.553 -74.203 -93.786; 24.966 112 -18.214];
            YCbCr_Off = (1/255) * [16 128 128];
            ColorTC{5}=[0.2990,-0.1471,0.6148;0.5870,-0.2888,-0.5148;0.1140,0.4359,-0.1000]; %YUV
            ColorTC{6}=[1,-1/3,-1/3;0,2/3,-1/3;0,-1/3,2/3]; %nRGB
            ColorTC{7}=[0.6070,-0.0343,-0.3940;0.1740,0.2537,-0.3280;0.2000,-0.2193,0.7220]; %nXYZ
                 
            % Build the transformation matrix
            transform = zeros(3, numel(ColorTC)*3);            
            for i=1:numel(ColorTC)                
                transform(:, 1+(i-1)*3:i*3) = ColorTC{i}; % transform=[RGB XYZ YIQ III YUV nRGB nXYZ];
            end
            
%             % not supported yet
%             for i=1:images
%                 
%                 YCBCR=rgb2ycbcr(img(:,:,:,i));
% 
%                 HSV=rgb2hsv(img(:,:,:,i));
%                 conv(:,:,1:3,i)=YCBCR(:,:,1:3);
%                 conv(:,:,4:6,i)=HSV(:,:,1:3);
% 
%             end 
%             conv1   = reshape(conv,row*col,6,images);

            fsize = self.h * self.w;
            rgb = double(reshape(self.db, fsize, self.ch, [])); 
            
            if (to22)
                % 3 + 3 for YCbCr, HSV
                tdb = zeros(fsize, size(transform, 2) + 3 + 3, images);
            else
                tdb = zeros(fsize, size(transform, 2), images);
            end           
            
            % Set Max, Min for normalization purpose
            maxT            = transform;
            maxT(maxT < 0)  = 0;
            channelMax      = ([255 255 255] * maxT);
            
            minT            = transform;
            minT(minT > 0)  = 0;
            channelMin      = ([255 255 255] * minT);
            
            % Required range
            newMax          = ones(1, size(transform, 2))*255;
            newMin          = ones(1, size(transform, 2))*0;
                        
            for i=1:self.n   
                temp = rgb(:,:,i)*transform;       
                
                if(normalized)           
                    %((x - channelMin) * ((newMax - newMin)/ (channelMax - channelMin))) + newMin
                    temp = bsxfun(@minus, temp, channelMin);
                    temp = bsxfun(@times, temp, (newMax - newMin)./ (channelMax - channelMin));
                    temp = bsxfun(@plus, temp, newMin);
                end          
                
                assert(uint8(max(max(temp))) <= max(newMax));
                assert(uint8(min(min(temp))) >= min(newMin));
                
                if (to22)
                    % YCbCr/HSV Transformation (done explicitely)
                    % Use this section only if the normalization
                    % range is [0, 255]
                    % temp2, temp3 will always be in the range [0, 255]
                    temp2 = reshape(rgb2ycbcr(reshape(rgb(:,:,i), self.h, self.w, [])), fsize, []);
                    %temp2 = rgb * YCbCr_T + repmat(YCbCr_Off, row*col, 1)                 
                    temp3 = reshape(rgb2hsv(reshape(rgb(:,:,i), self.h, self.w, [])), fsize, []);

                    assert(uint8(max(max(temp2))) <= max(newMax));
                    assert(uint8(min(min(temp2))) >= min(newMin));
                    assert(uint8(max(max(temp3))) <= max(newMax));
                    assert(uint8(min(min(temp3))) >= min(newMin));

                    tdb(:,:,i) = [temp temp2 temp3];
                    
                else
                    tdb(:,:,i) = uint8(temp);
                    
                end
            end
            clear rgb;
            
            % not supported yet
%             for i=1:images
%                 coo(:,22:27,i)=conv1(:,1:6,i);
%             end

            % Perform the selection (Mustapha's model)
            tdb2(:,1:6,:)   = tdb(:,1:6,:);
            tdb2(:,7:11,:)  = tdb(:,8:12,:);
            tdb2(:,12:13,:) = tdb(:,14:15,:);
            tdb2(:,14:15,:) = tdb(:,17:18,:);
            
            if (all22)
                tdb2(:,16:17,:) = tdb(:,20:21,:);
                tdb2(:,18:22,:) = tdb(:,23:27,:);
            end
            % % %  coo2(:,23:25,:)=dcs(:,:,:);            
            clear tdb;
            
            if (to22)
                self.db = reshape(tdb2, self.h, self.w, 22, self.n);
            else
                self.db = reshape(tdb2, self.h, self.w, 15, self.n);
            end        
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end
    
    methods (Access = private)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
        function init_db_fields__(self)
            import nnf.db.Format;
            
            if (self.format == Format.H_W_CH_N)
                [self.h, self.w, self.ch, self.n] = size(self.db);

            elseif (self.format == Format.H_N)
                self.w = 1;
                self.ch = 1;
                [self.h, self.n] = size(self.db);

            elseif (self.format == Format.N_H_W_CH)
                [self.n, self.h, self.w, self.ch] = size(self.db);

            elseif (self.format == Format.N_H)
                self.w = 1;
                self.ch = 1;
                [self.n, self.h] = size(self.db);
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end
    
    methods 
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Dependant property Implementations
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function db = get.db_convo_th(self)
            % db compatible for convolutional networks.

            % Imports
            import nnf.db.Format; 
            
            % N x CH x H x W
            if (self.format == Format.N_H_W_CH || self.format == Format.H_W_CH_N)
                db = permute(self.db_scipy, [1 4 2 3]);
                
            % N x 1 x H x 1
            elseif (self.format == Format.N_H || self.format == Format.H_N)
                db = reshape(self.db_scipy, self.n, 1, self.h, 1);

            else
                error('Unsupported db format');
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function db = get.db_convo_tf(self)
            % db compatible for convolutional networks.
            
            % Imports
            import nnf.db.Format; 
            
            % N x H x W x CH
            if (self.format == Format.N_H_W_CH || self.format == Format.H_W_CH_N)
                db = self.db_scipy;

            % N x H
            elseif (self.format == Format.N_H || self.format == Format.H_N)
                db = self.db_scipy(:, :, 1, 1);

            else
                error('Unsupported db format');
            end
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function db = get.db_scipy(self)
            % db compatible for scipy library.

            % Imports
            import nnf.db.Format; 
            
            % N x H x W x CH or N x H  
            if (self.format == Format.N_H_W_CH || self.format == Format.N_H)
                db = self.db;
                
            % H x W x CH x N
            elseif (self.format == Format.H_W_CH_N)
                db = permute(self.db,[4 1 2 3]);                

            % H x N
            elseif (self.format == Format.H_N)
                db = permute(self.db,[2 1]);
                
            else
                error('Unsupported db format');
            end
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function db = get.features_scipy(self)
            % 2D feature matrix (double) compatible for scipy library.   
            db = double(reshape(self.db_scipy, self.n, self.h * self.w * self.ch));
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function db = get.db_matlab(self)
            % db compatible for matlab.
            
            % Imports
            import nnf.db.Format; 

            % H x W x CH x N or H x N  
            if (self.format == Format.H_W_CH_N || self.format == Format.H_N)
                db = self.db;

            % N x H x W x CH
            elseif (self.format == Format.N_H_W_CH)
                db = permute(self.db,[2 3 4 1]);

            % N x H
            elseif (self.format == Format.N_H)
                db = permute(self.db,[2 1]);

            else
                raise Exception("Unsupported db format");
            end
        end        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function db = get.features(self) 
            % 2D feature matrix (double) compatible for matlab.
            db = double(reshape(self.db_matlab, self.h * self.w * self.ch, self.n));
        end  
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function value = get.im_ch_axis(self) 
            % Get image channel index for an image.
            % 
            % Exclude the sample axis.
            %
               
            % Imports
            import nnf.db.Format;
            
            if (self.format == Format.H_W_CH_N)
                value = 3;
            elseif (self.format == Format.H_N)
                value = 0;
            elseif (self.format == Format.N_H_W_CH)
                value = 3;
            elseif (self.format == Format.N_H)
                value = 0;
            else
                error('Unsupported db format')
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end
       
end


