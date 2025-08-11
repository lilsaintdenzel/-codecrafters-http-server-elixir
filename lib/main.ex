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
        lines = String.split(request, "\r\n")
        [request_line | header_lines] = lines
        [_, path, _] = String.split(request_line, " ")

        # Build the response
        response =
          case String.split(path, "/", trim: true) do
            [] ->
              "HTTP/1.1 200 OK\r\n\r\n"

            ["echo", body] ->
              "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: #{Kernel.byte_size(body)}\r\n\r\n#{body}"

            ["user-agent"] ->
              user_agent_header =
                Enum.find(header_lines, fn header ->
                  String.starts_with?(header, "User-Agent: ")
                end)

              user_agent = String.trim_leading(user_agent_header, "User-Agent: ")

              "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: #{Kernel.byte_size(user_agent)}\r\n\r\n#{user_agent}"

            ["files", filename] ->
              directory = Application.get_env(:codecrafters_http_server, :directory)
              filepath = Path.join(directory, filename)

              if File.exists?(filepath) do
                {:ok, body} = File.read(filepath)
                "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: #{Kernel.byte_size(body)}\r\n\r\n#{body}"
              else
                "HTTP/1.1 404 Not Found\r\n\r\n"
              end

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
  def main(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [directory: :string])
    directory = Keyword.get(opts, :directory)
    Application.put_env(:codecrafters_http_server, :directory, directory)

    # Start the Server application
    {:ok, _pid} = Application.ensure_all_started(:codecrafters_http_server)

    # Run forever
    Process.sleep(:infinity)
  end
end
