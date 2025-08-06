defmodule Server do
  use Application

  def start(_type, _args) do
    Supervisor.start_link([{Task, fn -> Server.listen() end}], strategy: :one_for_one)
  end

  def listen() do
    # You can use print statements as follows for debugging, they'll be visible when running tests.
    IO.puts("Logs from your program will appear here!")

    # Uncomment this block to pass the first stage
    #
    # # Since the tester restarts your program quite often, setting SO_REUSEADDR
    # # ensures that we don't run into 'Address already in use' errors
     {:ok, socket} = :gen_tcp.listen(4221, [:binary, active: false, reuseaddr: true])
     {:ok, _client} = :gen_tcp.accept(socket)
     {:ok, client} = :gen_tcp.accept(socket)
     {:ok, packet} = :gen_tcp.recv(client, 0)

  if String.contains?(packet, "GET / HTTP/1.1") do
      {:ok} = :gen_tcp.send(client, "HTTP/1.1 200 OK\r\n\r\n")
    else
      {:ok} = :gen_tcp.send(client, "HTTP/1.1 404 Not Found\r\n\r\n")
    end    # ...existing code...
    
    {:ok, socket} = :gen_tcp.listen(4221, [:binary, active: false, reuseaddr: true])
    IO.puts("Listening on port 4221")
    
    loop = fn loop ->
      {:ok, client} = :gen_tcp.accept(socket)
      {:ok, request} = :gen_tcp.recv(client, 0)
      [request_line | _] = String.split(request, "\r\n")
      [_method, path | _] = String.split(request_line, " ")
    
      response =
        case path do
          "/" -> "HTTP/1.1 200 OK\r\n\r\n"
          _ -> "HTTP/1.1 404 Not Found\r\n\r\n"
        end
    
      :gen_tcp.send(client, response)
      :gen_tcp.close(client)
      loop.(loop)
    end
    
    loop.(loop)
    
    # ...existing code...
  end
end

defmodule CLI do
  def main(_args) do
    # Start the Server application
    {:ok, _pid} = Application.ensure_all_started(:codecrafters_http_server)

    # Run forever
    Process.sleep(:infinity)
  end
end
