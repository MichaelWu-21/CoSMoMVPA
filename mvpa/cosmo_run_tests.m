function did_pass=cosmo_run_tests(varargin)
% run unit and documentation tests
%
% did_pass=cosmo_run_tests(['verbose',v]['output',fn])
%
% Inputs:
%   '-verbose'        do not run with verbose output
%   '-logfile',fn     store output in a file named fn (optional, if omitted
%                     output is written to the terminal window)
%   'file.m'          run tests in 'file.m'
%   '-no_doctest'     skip doctest
%   '-no_unittest'    skip unittest
%
% Examples:
%   % run tests with defaults
%   cosmo_run_tests
%
%   % run with non-verbose output
%   cosmo_run_tests('verbose',false);
%
%   % explicitly set verbose output and store output in file
%   cosmo_run_tests('verbose',true,'output','~/mylogfile.txt');
%
% Notes:
%   - This class requires the xUnit framework by S. Eddings (2009),
%     BSD License, http://www.mathworks.it/matlabcentral/fileexchange/
%                         22846-matlab-xunit-test-framework
%   - Doctest functionality was inspired by T. Smith.
%   - Documentation test classes are in CoSMoMVPA's tests/ directory;
%     CosmoDocTest{Case,Suite} extend the xUnit classes Test{Case,Suite}.
%   - Documentation tests can be added in the help section of functions in
%     CoSMoMVPA's mvpa/ directory. A doctest is specified in the comment
%     header section of an .m file; it is based on the text that is
%     showed by the command 'help the_function'
%
% %     (this example pretends to be the help of a function definition)
% %
% %     (other documentation here ...)
% %
% %     Example:                     % legend: line  block  type  test-type
% %         % this is a comment               %  1      1     C     C
% %         negative_four=-4;                 %  2      1     E     P 1.1
% %         sixteen=negative_four^2;          %  3      1     E     P 1.2
% %         abs([negative_four; sixteen])     %  4      1     E     E 1.1
% %         > 4                               %  5      1     W     W 1.1.1
% %         > 16                              %  6      1     W     W 1.1.2
% %         %                                 %  7      1     C     C
% %         nine=3*3;                         %  8      1     E     P 1.3
% %         abs(negative_four-nine)           %  9      1     E     E 1.2
% %         > 13                              % 10      1     W     W 1.2.1
% %                                           % 11            S     S
% %         unused=3;                         % 12      2     E     E 2.1
% %                                           % 13            S     S
% %         postfix=' is useful'              % 14      3     E     P 3.1
% %         disp({@abs postfix})              % 15      3     E     E 3.1
% %         >   @abs    ' is useful '         % 16      3     W     W 3.1.1
% %
% %     (more documentation here ['offside position'; see (3) below] ...)
%
%     The right-hand side shows (for clarification) four columns with line
%     number, block number, type and test-type. Doctests are processed as
%     follows:
%     1) A doctest section starts with a line containing just 'Example'
%        (or 'Examples:', 'example' or other variants; to be exact,
%        the regular expression to be matched is '^\s*[eE]xamples?:?\s*$').
%     2) The indent level is the number of spaces after the first non-empty
%        line after the Example line.
%     3) A doctest section ends whenever a line is found with a lower
%        indent level ('offside rule').
%     4) Only a single doctest section is supported. If multiple doctest
%        sections are found an error is raised.
%     5) Doctests are split in blocks by empty lines. (A line containing
%        only spaces is considered empty; a line with comment is considered
%        non-empty.)
%     6) In a first pass over all doctest lines, each line is assigned a
%        type:
%        + (E)xpression (string that can be evaluated by matlab)
%        + (W)ant       (expected output from evaluating an expression)
%        + (C)omment    (not an 'E' or 'W' line; contains '%' character)
%        + (S)pace      (white-space, i.e. not 'E', 'W' or 'C' line)
%     7) In a second pass, 'E' lines followed by another 'E' line are
%        set to the (P)reamble state (see test-type column, above).
%        Preamble lines can assign values to variables, but should not
%        produce output.
%        Non-preamble expression lines followed by one or more W-lines
%        should produce the output indicated by these W-lines.
%     8) A single doctest is run as follows:
%        - each block is processed separately
%        - for each line with test-type E (in each block):
%          + if it is not followed by one or more W-lines, then the
%            expression is ignored.
%          + otherwise:
%            * run all preceding preamble lines in the block
%              # if this produces non-empty output or an error, the test
%                fails.
%            * run the line with test-type E
%              # if this produces an error, the test fails
%            * compare the output of the previous step with the W-lines
%              # comparison of equality is somewhat 'lenient':
%                + equality is based on the output without the ' ans = '
%                  prefix string that matlab gives when showing output
%                + both the output of the W-lines and the evaluated output
%                  is compared after splitting the string by white-space
%                  characters. For example, if the real output is 'foo bar'
%                  and the expected output is '   foo   bar ', the test
%                  passes
%                + if the previous string comparison does not pass the
%                  test, an attempt is made to convert both the output of
%                  the W-lines and the evaluated output to a numeric array.
%                  If this conversion is succesfull and both arrays are
%                  equal, the test passes.
%                + if the conversion to numeric does not make the test
%                  pass, the W-lines are evaluated (and any ' ans = '
%                  prefix is removed). If this evaluation is succesfull
%                  (does not raise an exception) in is equal to the
%                  evaluated output, the test passes.
%              # if none of the above attempts make the test pass, the test
%                fails.
%            * if no test has failed, the test passes
%        - To illustrate, in the example above:
%          + E-1.1 is executed after P-1.1 and P-1.2; evaluating P-1.[1-2]
%            should not give output. The output of evaluating E-1.1
%            should be W-1.1.1 and W-1.1.2
%          + E-1.2 is executed after P-1.1, P-1.2, and P-1.3; evaluating
%            P-1.[1-3] should not give output. The output of evaluating
%            E-1.2 should be W-1.2.1.
%          + E-2.1 is ignored, because there is no corresponding W-2.1.*
%          + E-3.1 is executed after P-3.1; evaluating P-3.1 should
%            not give ouput. The output of evaluating E-1.3 should be
%            W-3.1.1.
%     9) The suite passes if all tests pass
%
% NNO Jul 2014

    orig_pwd=pwd();
    pwd_resetter=onCleanup(@()cd(orig_pwd));

    [opt,args]=get_opt(varargin{:});

    run_doctest=~opt.no_doctest;
    run_unittest=~opt.no_unittest;
    opt.doctest_location=[];

    has_logfile=~isempty(opt.logfile);

    if has_logfile && run_doctest && run_unittest
        error('Cannot have logfile with both doctest and unittest');
    end

    runners={@run_doctest_helper,@run_unittest_helper};
    did_pass=all(cellfun(@(runner) runner(opt,args),runners));


function did_pass=run_doctest_helper(opt,unused)
    did_pass=true;

    location=opt.doctest_location;
    if ~ischar(location)
        return;
    elseif isempty(location)
        location=get_default_dir('doc');
    end

    if cosmo_wtf('is_octave')
        cosmo_warning('Doctest not (yet) available for GNU Octave, skip');
        return
    end

    % xUnit is required
    cosmo_check_external('xunit');

    % run test using custom CosmoDocTestSuite
    cd(opt.run_from_dir);
    suite=CosmoDocTestSuite(location);
    if opt.verbose
        monitor_constructor=@VerboseTestRunDisplay;
    else
        monitor_constructor=@TestRunDisplay;
    end

    has_logfile=ischar(opt.logfile);
    if has_logfile
        fid=fopen(opt.logfile,'w');
        file_closer=onCleanup(@()fclose(fid));
    else
        fid=1;
    end

    monitor=monitor_constructor(fid);
    did_pass=suite.run(monitor);


function did_pass=run_unittest_helper(opt,args)
    did_pass=true;

    location=opt.unittest_location;
    if ~ischar(location)
        return;
    elseif isempty(location)
        location=get_default_dir('unit');
        args{end+1}=location;
    end

    cd(opt.run_from_dir);

    test_runner=get_test_field('runner');
    did_pass=test_runner(args{:});



function s=get_all_test_runners_struct()
    s=struct();
    s.moxunit.runner=@moxunit_runtests;
    s.moxunit.arg_with_value={'-coverage_dir',...
                                 '-coveralls_json',...
                                 '-cobertura_xml',...
                                 '-junit_xml'};

    s.xunit.runner=@runtests;
    s.xunit.arg_with_value={};

function key=get_test_runner_name()
    runners_struct=get_all_test_runners_struct();
    keys=fieldnames(runners_struct);

    present_ids=find(cosmo_check_external(keys,false));

    if isempty(present_ids)
        raise_exception=true;
        cosmo_check_external(keys, raise_exception);
    end

    key=keys{present_ids};


function value=get_test_field(sub_key)
    key=get_test_runner_name();
    s=get_all_test_runners_struct();
    value=s.(key).(sub_key);


function d=get_default_dir(name)
    switch name
        case 'root'
            d=fileparts(fileparts(mfilename('fullpath')));

        case 'unit'
            d=fullfile(get_default_dir('root'),'tests');

        case 'doc'
            d=fullfile(get_default_dir('root'),'mvpa');
    end


function [opt,passthrough_args]=get_opt(varargin)
    defaults=struct();
    defaults.verbose=false;
    defaults.no_doctest=false;
    defaults.no_unittest=false;
    defaults.logfile=[];
    defaults.unittest_location='';
    defaults.doctest_location='';

    n_args=numel(varargin);
    passthrough_args=varargin;
    keep_in_passthrough=true(1,n_args);
    k=0;

    arg_with_value=get_test_field('arg_with_value');
    opt=defaults;
    opt.run_from_dir=get_default_dir('unit');

    while k<n_args
        k=k+1;
        arg=varargin{k};

        switch arg
            case '-verbose'
                opt.verbose=true;

            case '-no_doctest'
                opt.no_doctest=true;
                keep_in_passthrough(k)=false;

            case '-no_unittest'
                opt.no_unittest=true;
                keep_in_passthrough(k)=false;

            case '-logfile'
                [opt.logfile,k]=next_arg(varargin,k);

            otherwise
                is_option=~isempty(regexp(arg,'^-','once'));

                if is_option
                    arg_has_value=~isempty(strmatch(arg,arg_with_value));
                    if arg_has_value
                        k=k+1;
                    end
                else
                    test_location=get_location(arg);
                    passthrough_args{k}=test_location;

                    opt.unittest_location=test_location;
                    opt.doctest_location=test_location;
                end
        end
    end

    passthrough_args=passthrough_args(keep_in_passthrough);
    if opt.no_unittest
        opt.unittest_location=[];
    end

    if opt.no_doctest
        opt.doctest_location=[];
    end

function full_path=get_location(location)
    parent_dirs={'',get_default_dir('unit'),get_default_dir('doc')};
    n=numel(parent_dirs);
    for use_which=[false,true]
        for k=1:n
            full_path=fullfile(parent_dirs{k},location);
            if isdir(full_path) || ~isempty(dir(full_path))
                return;
            end

            if use_which && isdir(parent_dirs{k})
                orig_pwd=pwd();
                cleaner=onCleanup(@()cd(orig_pwd));
                cd(parent_dirs{k});
                full_path=which(location);
                if ~isempty(full_path)
                    return;
                end
                clear cleaner;
            end
        end
    end


    error('Unable to find ''%s''',location);


function [value,next_k]=next_arg(args,k)
    n=numel(args);
    next_k=k+1;
    if next_k>n
        error('missing argument after ''%s''',args{k});
    end
    value=args{next_k};
