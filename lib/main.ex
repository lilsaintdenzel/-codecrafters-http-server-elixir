defmodule Server do
  use Application

  def start(_type, _args) do
    Supervisor.start_link([{Task, fn -> Server.listen() end}], strategy: :one_for_one)
  end

  def listen() do
    IO.puts("Logs from your program will appear here!")

    {:ok, socket} = :gen_tcp.listen(4221, [:binary, active: false, reuseaddr: true])
    IO.puts("Listening on port 4221")

    loop = fn loop ->
      {:ok, client} = :gen_tcp.accept(socket)

      spawn(fn ->
        # Read the request
        {:ok, request} = :gen_tcp.recv(client, 0)
        [request_line | _] = String.split(request, "\r\n")
        [_, path, _] = String.split(request_line, " ")

        # Build the response
        response =
          case path do
            "/" ->
              "HTTP/1.1 200 OK\r\n\r\n"

            _ ->
              "HTTP/1.1 404 Not Found\r\n\r\n"
          end

        # Send the response
        :gen_tcp.send(client, response)

        # Close the connection
        :gen_tcp.close(client)
      end)

      loop.(loop)
    end

    loop.(loop)
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
