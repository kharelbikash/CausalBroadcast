defmodule User do
  defp init_start(name) do
    %{ myname: name,
       mail_box: []
     }
  end
  def start(name) do
    pid = spawn( User,:run,[init_start(name)] )
    case :global.register_name(name,pid) do
      :yes -> pid
      :no  -> :error
    end
  end
  def subscribe(u,t) do
    send(:global.whereis_name(u), {:input, :subscrption, :global.whereis_name(u),t})

  end
  def run(state) do
    state = receive do
        {:input, :subscrption, u,t} ->
          case :global.whereis_name(t)  do
            :undefined ->  pid =TopicManager.start(t)
              send(pid,{:subscribe,u})
              state
              _ ->
              pid= :global.whereis_name(t)
              send(pid,{:subscribe,u})
              state
            end

        {:input, :unsubscrption, u,t} ->
           case :global.whereis_name(t)  do
             :undefined -> IO.puts("error in input")
               _ ->
               pid= :global.whereis_name(t)
               send(pid,{:unsubscribe,u})
               state
             end

        {:input, :post, u, t, content} ->
           send(t,{:post, u,t, content})
           state

        {:mailbox,topic,content} ->
             state= update_in(state,[:mail_box],fn(list) ->
                 [{topic,content}|list]
               end
             )
             state

        {:input,:fetch_news} ->
            printContent(state.mail_box)
      end
        run(state)
  end
  def unsubscribe(u,t) do
      send(:global.whereis_name(u), {:input, :unsubscrption, :global.whereis_name(u),t})
  end
  def post(u,t,content) do
      send(:global.whereis_name(u), {:input, :post, :global.whereis_name(u),:global.whereis_name(t), content})
  end
  def fetch_news(u) do
    send(:global.whereis_name(u),{:input,:fetch_news})
  end
  defp printContent([]), do: []
  defp printContent([{topic,content}|rest]) do
    IO.puts("content:"<>inspect(content))
    printContent(rest)
  end
end

defmodule TopicManager do
  defp init_start(topic_name) do
    %{
      topic_name: topic_name,
      content: [],
      sub_user: []
  }
  end
  def start(topic_name) do
    pid = spawn( TopicManager,:run,[init_start(topic_name)] )
    case :global.register_name(topic_name,pid) do
      :yes -> pid
      :no  -> :error
    end
  end
  def run(task_state) do
        #IO.puts("Topic Registered:" <> inspect(task_state))
    task_state= receive do
      {:subscribe,u} ->
        task_state= update_in(task_state,[:sub_user],fn(list) ->
            [{u}|list]
          end
        )
        task_state
        {:unsubscribe,u} ->
          task_state= update_in(task_state,[:sub_user],fn(list) ->
            List.delete(list,{u})
            end
            )
            task_state
        {:post, u,t,content} ->
          task_state= update_in(task_state,[:content],fn(list) ->
            [{u,t,content}|list]
            end
          )
          sendMsg(task_state.sub_user,t,content)
          task_state
    end
    run(task_state)
  end

  def sendMsg([],_,_), do: []

  def sendMsg([{u}|rest],topic,content) do
    send(u,{:mailbox,topic,content})
    sendMsg(rest,topic,content)
  end
end

bob=User.start("bob")
User.subscribe("bob","computing")
:timer.sleep(100)
steve =User.start("steve")
User.subscribe("steve","computing")
:timer.sleep(100)
User.subscribe("steve","database")
:timer.sleep(100)
User.unsubscribe("steve","database")
:timer.sleep(100)
User.post("bob","computing","just found a prime number")
:timer.sleep(100)
User.post("steve","computing","just found another prime number")
:timer.sleep(100)
User.fetch_news("bob")
