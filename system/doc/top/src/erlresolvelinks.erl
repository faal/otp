-module(erlresolvelinks). 

%% ------ VERY IMPORTANT ------
%%
%% Original location for this file: 
%% /clearcase/otp/internal_tools/integration/scripts/resolve_links/
%% When updating this file, copy the source to 
%% /usr/local/otp/patch/share/program/
%% and place .beam files (compiled with correct release) in all 
%% /usr/local/otp/patch/share/program/<release>
%% for releases >= R10B
%%
%% ----------------------------

-export([make/1, do_make/1, do_make/2, do_make/3]).
-include_lib("kernel/include/file.hrl").

-define(JAVASCRIPT_NAME, "erlresolvelinks.js").

make([RootDir]) ->
    do_make(RootDir);
make([RootDir, DestDir]) ->
    do_make(RootDir, DestDir);
make([RootDir, DestDir, Name]) ->
    do_make(RootDir, DestDir, Name).

do_make(RootDir) ->
    DestDir = filename:join(RootDir, "doc"),
    do_make(RootDir, DestDir).

do_make(RootDir, DestDir) ->
    do_make(RootDir, DestDir, ?JAVASCRIPT_NAME).

do_make(RootDir, DestDir, Name) ->
    %% doc/Dir
    %% erts-Vsn
    %% lib/App-Vsn
    DocDirs0 = get_dirs(filename:join([RootDir, "doc"])),
    DocDirs = lists:map(fun(Dir) -> 
				D = filename:join(["doc", Dir]),
				{D, D} end, DocDirs0),

    ErtsDirs = latest_app_dirs(RootDir, ""), 
    AppDirs = latest_app_dirs(RootDir, "lib"),
    
    AllAppDirs = 
	lists:map(
	  fun({App, AppVsn}) -> {App, filename:join([AppVsn, "doc", "html"])}
	  end, ErtsDirs ++ AppDirs),

    AllDirs = DocDirs ++ AllAppDirs,
    {ok, Fd} = file:open(filename:join([DestDir, Name]), [write]),
    UTC = calendar:universal_time(),
    io:fwrite(Fd, "/* Generated by ~s at ~w UTC */\n", 
	      [atom_to_list(?MODULE), UTC]),
    io:fwrite(Fd, "function erlhref(ups, app, rest) {\n", []),
    io:fwrite(Fd, "    switch(app) {\n", []),
    lists:foreach(
      fun({Tag, Dir}) ->
	      io:fwrite(Fd, "    case ~p:\n", [Tag]),
	      io:fwrite(Fd, "        location.href=ups + \"~s/\" + rest;\n",
			[Dir]),
	      io:fwrite(Fd, "        break;\n",	[])
      end, AllDirs),
    io:fwrite(Fd, "    default:\n", []),
    io:fwrite(Fd, "        location.href=ups + \"Unresolved\";\n", []),
    io:fwrite(Fd, "    }\n", []),
    io:fwrite(Fd, "}\n", []),
    file:close(Fd),
    ok.
    
get_dirs(Dir) ->
    {ok, Files} = file:list_dir(Dir),
    AFiles = 
	lists:map(fun(File) -> {File, filename:join([Dir, File])} end, Files),
    lists:zf(fun is_dir/1, AFiles).

is_dir({File, AFile}) ->
    {ok, FileInfo} = file:read_file_info(AFile),
    case FileInfo#file_info.type of
	directory ->
	    {true, File};
	_  ->
	    false
    end.

latest_app_dirs(RootDir, Dir) ->
    ADir = filename:join(RootDir, Dir),
    RDirs0 = get_dirs(ADir),
    RDirs1 = lists:filter(fun is_app_dir/1, RDirs0),
    %% Build a list of {{App, VsnNumList}, AppVsn}
    SDirs0 = 
	lists:map(fun(AppVsn) ->
			  [App, VsnStr] = string:tokens(AppVsn, "-"),
			  VsnNumList = vsnstr_to_numlist(VsnStr),
			  {{App, VsnNumList}, AppVsn} end,
		  RDirs1),
    SDirs1 = lists:keysort(1, SDirs0),
    App2Dirs = lists:foldr(fun({{App, _VsnNumList}, AppVsn}, Acc) ->
				   case lists:keymember(App, 1, Acc) of
				       true ->
					   Acc;
				       false ->
					   [{App, AppVsn}| Acc]
				   end
			   end, [], SDirs1),
    lists:map(fun({App, AppVsn}) -> {App, filename:join([Dir, AppVsn])} end,
	      App2Dirs).

is_app_dir(Dir) ->
    case string:tokens(Dir, "-") of
	[_Name, Rest] ->
	    is_vsnstr(Rest);
	_  ->
	    false
    end.

is_vsnstr(Str) ->	
    case string:tokens(Str, ".") of
	[_] ->
	    false;
	Toks  ->
	    lists:all(fun is_numstr/1, Toks)
    end.

is_numstr(Cs) ->
    lists:all(fun(C) when $0 =< C, C =< $9 -> 
		      true;
		 (_) ->
		      false
	      end, Cs).

%% We know:

vsnstr_to_numlist(VsnStr) ->	    
    lists:map(fun(NumStr) -> list_to_integer(NumStr) end,
	      string:tokens(VsnStr, ".")).


     


    
