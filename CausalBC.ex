defmodule CausalBC do

  defp init_state(name,participants) do
    %{ myname: name,
       pending: [],
       participants: participants,
       ts: for p <- participants, into: %{} do
                {p,0}
           end
     }
  end

  def start(name,participants) do
    pid = spawn( CausalBC,:run, [init_state(name,participants)])
    case :global.register_name(name,pid) do
      :yes -> pid
      :no  -> :error
    end
  end

  def bc_send(msg,origin) do
    send(origin,{:input,:bc_initiate,msg})
  end

  def run(state) do
    IO.puts("#{state.myname}: " <> inspect(state.ts))
    state = receive do
      {:input,:bc_initiate,msg} ->
        state = update_in(state,[:ts,state.myname],fn(t) -> t+1 end)
        tsi = state.ts # ts[i] in pseudo code
        IO.puts("tsi"<> inspect(tsi))
           causal_bc_send(state,{:bc_msg,msg,tsi,state.myname})

        state

      {:output, :bc_rcvd,msg,origin_name} ->
        IO.puts("OUTPUT: #{inspect state.myname} got bcast #{msg} from #{inspect origin_name}")
        state

        {:bc_msg,msg,t,origin_name} ->
          IO.puts("tsjMap"<> inspect(t))
        state = update_in(state, [:pending], fn(list) ->
                                 [{msg,t,origin_name} | list]
                                  end
                          )
                        end

      readyMsgs = remove_pending(state,(state.pending))#####
      state = update_ts(readyMsgs,state)
      state = %{ state | pending: state.pending -- readyMsgs }

      if readyMsgs != [] do
        for {msg,_,origin_name} <- readyMsgs do
          send(self(),{:output,:bc_rcvd,msg,origin_name})
        end
      end
        run(state)
  end

  def update_ts([],state), do: state
  def update_ts([{m,t,j} | readyMsgs],state) do
     state = update_in(state,[:ts,j],fn(t) -> t+1 end)
     update_ts(readyMsgs,state)
  end
  ##########
  def remove_pending(_,[]), do: []
  def remove_pending(state,[{msg,t,j} | rest]) do
    if(Map.get(t,j) == state.ts[j]+1) do
      checks = for p <- state.participants , p != j do ####
          Map.get(t,p)<= state.ts[p]
      end

      if (Enum.member?(checks,true)) do
      #  state = update_in(state,[:ts,j],fn(t) -> t+1 end)
        [{msg,t,j} | remove_pending(state,rest)]
        #state
      else
        remove_pending(state,rest)
      end
    else
      remove_pending(state,rest)
    end
  end

  #####################


###########
  def causal_bc_send(state,msg) do
    for p <- List.delete(state.participants,state.myname) do
     pid = :global.whereis_name(p)
     if( state.myname == "p1") do
    :timer.sleep(5000)
      end
      send(pid,msg)
    end
  end
end

p1 = CausalBC.start("p1", ["p1","p2","p3","p4"])
p2 = CausalBC.start("p2", ["p1","p2","p3","p4"])
p3 = CausalBC.start("p3", ["p1","p2","p3","p4"])
p4 = CausalBC.start("p4", ["p1","p2","p3","p4"])


CausalBC.bc_send("Hello World!",p2)
:timer.sleep(200)
CausalBC.bc_send("Hello World!",p3)
:timer.sleep(200)
CausalBC.bc_send("Hello World again!",p2)
:timer.sleep(200)
CausalBC.bc_send("Hello World!",p4)
#CausalBC.bc_send("Hello again!",p1)
