defmodule Server do
  use Application

  def start(_type, _args) do
    Supervisor.start_link([{Task, fn -> Server.listen() end}], strategy: :one_for_one)
  end

  defp parse_headers(header_lines) do
    Enum.reduce(header_lines, %{}, fn header, acc ->
      case String.split(header, ": ", parts: 2) do
        [key, value] -> Map.put(acc, String.downcase(key), value)
        _ -> acc
      end
    end)
  end

  def listen() do
    IO.puts("Logs from your program will appear here!")

    {:ok, socket} = :gen_tcp.listen(4221, [:binary, active: false, reuseaddr: true])
    IO.puts("Listening on port 4221")

    accept_loop(socket)
  end

  defp accept_loop(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    spawn(fn -> handle_connection(client) end)
    accept_loop(socket)
  end

  defp handle_connection(client) do
    case :gen_tcp.recv(client, 0) do
      {:ok, request} ->
        {head, body} = 
          case String.split(request, "\r\n\r\n", parts: 2) do
            [head, body] -> {head, body}
            [head] -> {head, ""}
          end

        lines = String.split(head, "\r\n")
        [request_line | header_lines] = lines
        headers = parse_headers(header_lines)
        [method, path, _] = String.split(request_line, " ")

        # Build the response
        response = 
          case {method, String.split(path, "/", trim: true)} do
            {"GET", []} ->
              "HTTP/1.1 200 OK\r\n\r\n"

            {"GET", ["echo", echo_body]} ->
              accept_encoding = Map.get(headers, "accept-encoding", "")
              encodings = String.split(accept_encoding, ",") |> Enum.map(&String.trim/1)

              if "gzip" in encodings do
                compressed_body = :zlib.gzip(echo_body)
                "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Type: text/plain\r\nContent-Length: #{Kernel.byte_size(compressed_body)}\r\n\r\n#{compressed_body}"
              else
                "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: #{Kernel.byte_size(echo_body)}\r\n\r\n#{echo_body}"
              end

            {"GET", ["user-agent"]} ->
              user_agent = Map.get(headers, "user-agent")

              "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: #{Kernel.byte_size(user_agent)}\r\n\r\n#{user_agent}"

            {"GET", ["files", filename]} ->
              directory = Application.get_env(:codecrafters_http_server, :directory)
              filepath = Path.join(directory, filename)

              if File.exists?(filepath) do
                {:ok, file_body} = File.read(filepath)
                "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: #{Kernel.byte_size(file_body)}\r\n\r\n#{file_body}"
              else
                "HTTP/1.1 404 Not Found\r\n\r\n"
              end

            {"POST", ["files", filename]} ->
              directory = Application.get_env(:codecrafters_http_server, :directory)
              filepath = Path.join(directory, filename)
              File.write!(filepath, body)
              "HTTP/1.1 201 Created\r\n\r\n"

            _ ->
              "HTTP/1.1 404 Not Found\r\n\r\n"
          end

        # Handle Connection: close
        connection_header = Map.get(headers, "connection")

        final_response = 
          if connection_header == "close" do
            [resp_head, resp_body] = String.split(response, "\r\n\r\n", parts: 2)
            "#{resp_head}\r\nConnection: close\r\n\r\n#{resp_body}"
          else
            response
          end

        # Send the response
        :gen_tcp.send(client, final_response)

        # Decide whether to close or keep alive
        if connection_header == "close" do
          :gen_tcp.close(client)
        else
          handle_connection(client)
        end

      {:error, :closed} ->
        :gen_tcp.close(client)
    end
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
