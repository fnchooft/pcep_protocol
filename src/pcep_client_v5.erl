%%%-------------------------------------------------------------------
%%% @author Xinfeng
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 21. 十一月 2016 16:17
%%%-------------------------------------------------------------------
-module(pcep_client_v5).
-author("Xinfeng").

%% API
-export([]).
-define(PCEP_PORT,4189).

%% API
-export([start_link/1,start/1,timer_stop/1,pid_init/0,resource_init/0,pid_add/1,start_add/1,add/1]).

pid_init() ->
  ets:new(pid,[named_table,public]).

resource_init() ->
  ets:new(link_resource,[named_table,public]),
  Link_Num = linc_pcep_config:link_num(),
  {ok,Links} = linc_pcep_config:get_link(),
  linc_pcep_config:for(1,Link_Num, fun(I) ->
    Link_I = lists:nth(I,Links),
    ets:insert(link_resource,{Link_I,400})
  end
  ).

pid_add(SwitchId) ->
  Pid = start_link(SwitchId),
  ets:insert(pid,{SwitchId,Pid}).

start_link(SwitchId) ->
  spawn(pcep_client_v5,start,[SwitchId]).

start_add(Add_Info) ->
  spawn(pcep_client_v5,add,[Add_Info]).

add(Add_Info) ->
  Port = ?PCEP_PORT,
  {ok,Host} = application:get_env(linc,controller_ip),
  {ok,OpenMessage} = pcep_msg_create:open_msg_creating(),
  KeepaliveMessage = <<32,2,0,4>>,
  Link_Num = tuple_size(Add_Info),
  {ok,Ls_report_node_Message} = pcep_msg_create:ls_node_add_msg_creating(Add_Info),
  case Link_Num of
    0 ->
      io:format("No Link exist on the switch~n");
    1 ->
      {ok,Ls_link_add_local_Message} = pcep_msg_create:ls_link_add_local_msg_creating(Add_Info),
      {ok,Ls_link_add_remote_0_Message} = pcep_msg_create:ls_link_add_remote_msg_0_creating(Add_Info),
      {ok,Socket} = gen_tcp:connect(Host,Port,[binary,{packet,0}]),
      gen_tcp:send(Socket,OpenMessage),
      receive_data(Socket,[]),
      gen_tcp:send(Socket,KeepaliveMessage),
      receive_data(Socket,[]),
      gen_tcp:send(Socket,Ls_report_node_Message),
      gen_tcp:send(Socket,Ls_link_add_local_Message),
      gen_tcp:send(Socket,Ls_link_add_remote_0_Message),
      Pid = spawn(fun() -> receive_data1(Socket,[]) end),
      gen_tcp:controlling_process(Socket,Pid),
      timer_start(30000,fun() -> gen_tcp:send(Socket,KeepaliveMessage) end);
    _ ->
      Ls_link_add_remote_Message = pcep_msg_create:ls_link_add_remote_msg_creating(Add_Info),
      Ls_link_add_local_1_Message = pcep_msg_create:ls_link_add_local_msg_1_creating(Add_Info),
      {ok,Ls_link_add_local_0_Message} = pcep_msg_create:ls_link_add_local_msg_0_creating(Add_Info),
      {ok,Socket} = gen_tcp:connect(Host,Port,[binary,{packet,0}]),
      gen_tcp:send(Socket,OpenMessage),
      receive_data(Socket,[]),
      gen_tcp:send(Socket,KeepaliveMessage),
      receive_data(Socket,[]),
      gen_tcp:send(Socket,Ls_report_node_Message),
      gen_tcp:send(Socket,Ls_link_add_remote_Message),
      gen_tcp:send(Socket,Ls_link_add_local_1_Message),
      gen_tcp:send(Socket,Ls_link_add_local_0_Message),
      Pid = spawn(fun() -> receive_data1(Socket,[]) end),
      gen_tcp:controlling_process(Socket,Pid),
      timer_start(30000,fun() -> gen_tcp:send(Socket,KeepaliveMessage) end)
  end.

start(SwitchId) ->
  Port = ?PCEP_PORT,
  {ok,Host} = application:get_env(linc,controller_ip),
  {ok,OpenMessage} = pcep_msg_create:open_msg_creating(),
  KeepaliveMessage = <<32,2,0,4>>,
  Link_Num = linc_pcep_config:link_ip_num(SwitchId),
  {ok,Ls_report_node_Message} = pcep_msg_create:ls_report_node_msg_creating(SwitchId),
  case Link_Num of
    0 ->
      io:format("No Link exist on the switch~n");
    1 ->
      {ok,Ls_report_link_0_Message} = pcep_msg_create:ls_report_link_msg_0_creating(SwitchId),
      {ok,Socket} = gen_tcp:connect(Host,Port,[binary,{packet,0}]),
      gen_tcp:send(Socket,OpenMessage),
      receive_data(Socket,[]),
      gen_tcp:send(Socket,KeepaliveMessage),
      receive_data(Socket,[]),
      gen_tcp:send(Socket,Ls_report_node_Message),
      gen_tcp:send(Socket,Ls_report_link_0_Message),
      Pid = spawn(fun() -> receive_data1(Socket,[]) end),
      gen_tcp:controlling_process(Socket,Pid),
      timer_start(30000,fun() -> gen_tcp:send(Socket,KeepaliveMessage) end);
    _ ->
      Ls_report_link_1_Message = pcep_msg_create:ls_report_link_msg_1_creating(SwitchId),
      {ok,Ls_report_link_0_Message} = pcep_msg_create:ls_report_link_msg_0_creating(SwitchId),
      {ok,Socket} = gen_tcp:connect(Host,Port,[binary,{packet,0}]),
      gen_tcp:send(Socket,OpenMessage),
      receive_data(Socket,[]),
      gen_tcp:send(Socket,KeepaliveMessage),
      receive_data(Socket,[]),
      gen_tcp:send(Socket,Ls_report_node_Message),
      gen_tcp:send(Socket,Ls_report_link_1_Message),
      gen_tcp:send(Socket,Ls_report_link_0_Message),
      Pid = spawn(fun() -> receive_data1(Socket,[]) end),
      io:format("Pid in v3 is~p~n",[Pid]),
      gen_tcp:controlling_process(Socket,Pid),
      timer_start(30000,fun() -> gen_tcp:send(Socket,KeepaliveMessage) end)
  end.

receive_data(Socket,SoFar) ->
  receive
    {tcp,Socket,Bin} ->
      io:format(Bin);
    {tcp_close,Socket} ->
      list_to_binary(SoFar)
  end.

receive_data1(Socket,SoFar) ->   %% TODO
  receive
    {tcp,Socket,Bin} ->
      {H,L} = split_binary(Bin,2),
      if H =:= <<32,12>> ->
        io:format("PCIn Msg is ~p~n",[Bin]),
        PcrptMsg = pcep_msg_create:pcrpt_msg_creating(L),
        gen_tcp:send(Socket,PcrptMsg),
        receive_data1(Socket,[]);
        true ->
          receive_data1(Socket,[])
      end,
      io:format(Bin);
    {tcp_closed,Socket} ->
      list_to_binary(SoFar)
  end.

timer_start(Time,Fun) ->
  spawn(fun() -> tick(Time,Fun) end).

timer_stop(Process_name) ->
  Pid = whereis(Process_name),
  if Pid == undefined ->
    io:format("can not find process in register table")
  end,
  if true ->
    Pid ! stop
  end.

tick(Time,Fun) ->
  receive
    stop ->
      void
  after Time ->
    Fun(),
    tick(Time,Fun)
  end.