%%% Message passing utility.  
%%% User interface:
%%% logon(Name)
%%%     One user at a time can log in from each Erlang node in the
%%%     system messenger: and choose a suitable Name. If the Name
%%%     is already logged in at another node or if someone else is
%%%     already logged in at the same node, login will be rejected
%%%     with a suitable error message.
%%% logoff()
%%%     Logs off anybody at that node
%%% message(ToName, Message)
%%%     sends Message to ToName. Error messages if the user of this 
%%%     function is not logged on or if ToName is not logged on at
%%%     any node.
%%%
%%% One node in the network of Erlang nodes runs a server which maintains
%%% data about the logged on users. The server is registered as "messenger"
%%% Each node where there is a user logged on runs a client process registered
%%% as "mess_client" 
%%%
%%% Protocol between the client processes and the server
%%% ----------------------------------------------------
%%% 
%%% To server: {ClientPid, logon, UserName}
%%% Reply {messenger, stop, user_exists_at_other_node} stops the client
%%% Reply {messenger, logged_on} logon was successful
%%%
%%% To server: {ClientPid, logoff}
%%% Reply: {messenger, logged_off}
%%%
%%% To server: {ClientPid, logoff}
%%% Reply: no reply
%%%
%%% To server: {ClientPid, message_to, ToName, Message} send a message
%%% Reply: {messenger, stop, you_are_not_logged_on} stops the client
%%% Reply: {messenger, receiver_not_found} no user with this name logged on
%%% Reply: {messenger, sent} Message has been sent (but no guarantee)
%%%
%%% To client: {message_from, Name, Message},
%%%
%%% Protocol between the "commands" and the client
%%% ----------------------------------------------
%%%
%%% Started: messenger:client(Server_Node, Name)
%%% To client: logoff
%%% To client: {message_to, ToName, Message}
%%%
%%% Configuration: change the server_node() function to return the
%%% name of the node where the messenger server runs

-module(messenger).
-export([start_server/0, server/1, logon/1, logoff/0, message/2, client/2,message_to_all/1,get_status/1,stop_server/0]).

%%% Change the function below to return the name of the node where the
%%% messenger server runs
server_node() ->
    messenger@Arya.

%%% This is the server process for the "messenger"
%%% the user list has the format [{ClientPid1, Name1},{ClientPid22, Name2},...]
server(User_List) ->
    receive
        {From, logon, Name} ->
            file:write_file("D:/visual saving files 2/advanced programing 2/message project/users.dat",io_lib:fwrite("~p~n", [Name]),[append]),
            New_User_List = server_logon(From, Name, User_List),
            server(New_User_List);
        {From, logoff} ->
            New_User_List = server_logoff(From, User_List),
            server(New_User_List);
        {From, message_to, To, {Message,Cur_time}} ->
            server_transfer(From, To, {Message,Cur_time}, User_List),
            io:format("list is now: ~p~n", [User_List]),
            server(User_List);
        {From, message_to, {Message,Cur_time}} ->
            server_transfer(From,{Message,Cur_time}, User_List),
            server(User_List);
        {Name,stat} ->
            server_status(a,Name,User_List)
    end.

%%% Start the server
start_server() ->
    register(messenger, spawn(messenger, server, [[]])).
stop_server() ->
    exit(whereis(messenger),ok).

server_status(a,Name,User_List) -> server_status(a,Name,User_List,[]).

server_status(a,Name,[],Final) ->
    io:format("~p wants to know the online users: ~p~n",[Name,Final]);

server_status(a,Name,[{_,Fname}|Y2],Final) ->
    server_status(a,Name,Y2,[Fname]++Final).

read_users_file(Filename) ->
    case file:open(Filename, [read]) of
        {ok, Device} ->  
            try get_all_lines(Device)
                after file:close(Device)
            end;
        {error, _} -> []
    end.

get_all_lines(Device) ->
    case io:get_line(Device, "\n") of
        eof  -> [];
        Line -> [string:substr(Line, 1, string:length(Line) - 1)] ++ get_all_lines(Device)
    end.
%% Server adds a new user to the user list

server_logon(From, Name, User_List) ->
    %% check if logged on anywhere else
    case lists:keymember(Name, 2, User_List) of
        true -> 
            From ! {messenger, stop, user_exists_at_other_node},  %reject logon
            User_List;
        false ->
            From ! {messenger, logged_on},
            [{From, Name} | User_List]        %add user to the list
    end.

%%% Server deletes a user from the user list
server_logoff(From, User_List) ->
    lists:keydelete(From, 1, User_List).

server_transfer(From, {Message,Cur_time}, User_List) ->
     case lists:keysearch(From, 1, User_List) of
        false ->
             From ! {messenger, stop, you_are_not_logged_on};
     {value, {From, Name}} ->
             server_transfer(m,From, Name, {Message,Cur_time}, User_List)
    end.
% to check if a user is in the file (signed in)
check(_,[]) ->
    false;
check(Hto,[G|T2]) ->
    %G = atom_to_list(G),
    io:format("~p   ~p~n",[G,Hto]),
    case Hto == atom_to_list(G) of
        true -> 
            true;
        false -> 
            check(Hto,T2)
    end.
server_transfer(m,From, _, _, []) ->
     From ! {messenger, sent};
server_transfer(m,From, Name, {Message,Cur_time}, User_List) ->
    [{ToPid,To_2}|T] = User_List,
    file:write_file("D:/visual saving files 2/advanced programing 2/message project/mess.dat",io_lib:fwrite("Message to ~p : ~p on: ~p~n", [To_2,Message,Cur_time]),[append]),
    ToPid ! {message_from, Name, {Message,Cur_time}}, 
    server_transfer(m,From,Name,{Message,Cur_time},T);

%%% If the user exists, send the message
server_transfer(From, Name, To, {Message,Cur_time}, User_List) ->
    % Find the receiver and send the message
    List_infile = read_users_file("D:/visual saving files 2/advanced programing 2/message project/users.dat"),
    case check(To,List_infile) of  
        true ->
            case lists:keysearch(To, 2, User_List) of
                false ->
                    file:write_file("D:/visual saving files 2/advanced programing 2/message project/mess.dat",io_lib:fwrite("Message to ~p: ~p on: ~p~n", [To, Message,Cur_time]),[append]),
                    From ! {messenger, receiver_is_offile};
                {value, {ToPid, To}} ->
                    ToPid ! {message_from, Name, {Message,Cur_time}},
                    From ! {messenger, sent}  
            end;
        false ->
            From ! {messenger,receiver_not_found}
    end.
%%% Server transfers a message between user
server_transfer(From, To, {Message,Cur_time}, User_List) ->
    % check that the user is logged on and who he is
    case lists:keysearch(From, 1, User_List) of
        false ->
            From ! {messenger, stop, you_are_not_logged_on};
        {value, {From, Name}} ->
            server_transfer(From, Name, To, {Message,Cur_time}, User_List)
    end.

%%% User Commands

logon(Name) ->
    case whereis(mess_client) of 
        undefined ->
            register(mess_client, 
                     spawn(messenger, client, [server_node(), Name]));
        _ -> already_logged_on
    end.

logoff() ->
    mess_client ! logoff.

message(ToName, Message) ->
    case whereis(mess_client) of % Test if the client is running
        undefined ->
            not_logged_on;
        _ -> mess_client ! {message_to, ToName, Message},
             ok
end.
message_to_all(Message) ->
     case whereis(mess_client) of
        undefined ->
            not_logged_on;
        _ -> mess_client ! {message_to,Message},
            ok
end.
get_status(ToName) ->
    case whereis(mess_client) of
        undefined ->
            not_logged_on;
        _ -> mess_client ! {ToName,status},
            ok
    end.
%% The client process which runs on each server node
client(Server_Node, Name) ->
    {messenger, Server_Node} ! {self(), logon, Name},
    await_result(),
    client(Server_Node).

client(Server_Node) ->
    receive
        logoff ->
            {messenger, Server_Node} ! {self(), logoff},
            exit(normal);
        {message_to, ToName, Message} ->
			Cur_time = calendar:local_time(),
            {messenger, Server_Node} ! {self(), message_to, ToName, {Message,Cur_time}},
            await_result();
        {message_to, Message} ->
            Cur_time = calendar:local_time(),
            {messenger, Server_Node} ! {self(), message_to, {Message,Cur_time}},
            await_result();
        {message_from, FromName, {Message,Cur_time}} ->
            {_,{Current_hour,Current_minute,Current_second}} = Cur_time,
            io:format("Message from ~p: ~p on: ~p:~p:~p~n", [FromName, Message,Current_hour,Current_minute,Current_second]);
        {ToName,status} ->
            {messenger, Server_Node} ! {ToName, stat}
    end,
    client(Server_Node).

%%% wait for a response from the server 
await_result() ->
    receive
        {messenger, stop, Why} -> % Stop the client 
            io:format("~p~n", [Why]),
            exit(normal);
        {messenger, What} ->  % Normal response
            io:format("~p~n", [What])
    end.