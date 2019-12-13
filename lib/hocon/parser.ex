defmodule Hocon.Parser do

  alias Hocon.Tokenizer
  alias Hocon.Document

  @doc"""

  Parses and decodes a hocon string and returns a map

  ## options

    * `:convert_numerically_indexed` - if set to true then numerically-indexed objects are converted to arrays
    * `:strict_conversion` - if set to `true` then numerically-indexed objects are only converted to arrays
       if all keys are numbers

  """
  def decode(string, opts \\ []) do
    try do
      {:ok, decode!(string, opts)}
    catch
      error -> error
    end

  end

  @doc"""
  Similar to `decode/2` except it will unwrap the error tuple and raise
  in case of errors.
  """
  def decode!(string, opts \\ []) do
    with {:ok, ast} <- Tokenizer.decode(string) do
      with {[], result } <- ast
                            |> contact_rule([])
                            |> parse_root() do
        Document.convert(result, opts)
      end
    end
  end

  def contact_rule([], result) do
    Enum.reverse(result)
  end
  def contact_rule([{:unquoted_string, simple_a}, :ws, {:unquoted_string, simple_b}|rest], result) do
    contact_rule([{:unquoted_string, simple_a <> " " <> simple_b} | rest], result)
  end
  def contact_rule([{:unquoted_string, simple_a}, :ws, int_b|rest], result) when is_number(int_b) do
    contact_rule([{:unquoted_string, simple_a <> " " <> to_string(int_b)} | rest], result)
  end
  def contact_rule([int_a, {:unquoted_string, string_b} |rest], result) when is_number(int_a) do
    contact_rule([{:unquoted_string, to_string(int_a) <> string_b} | rest], result)
  end
  def contact_rule([int_a, :ws, int_b|rest], result) when is_number(int_a) and is_number(int_b) do
    contact_rule([{:unquoted_string, to_string(int_a) <> " " <> to_string(int_b)} | rest], result)
  end
  def contact_rule([{:unquoted_string, simple_a}, {:string, simple_b}|rest], result) do
    contact_rule([{:unquoted_string, simple_a <> simple_b} | rest], result)
  end
  def contact_rule([{:string, simple_a}, {:unquoted_string, simple_b}|rest], result) do
    contact_rule([{:unquoted_string, simple_a <> simple_b} | rest], result)
  end
  def contact_rule([{:string, simple_a}, {:string, simple_b}|rest], result) do
    contact_rule([{:string, simple_a <> simple_b} | rest], result)
  end
  def contact_rule([other|rest], result) do
    contact_rule(rest, [other | result])
  end

  def parse_root([:open_curly | rest]) do
    parse_object(rest, Document.new())
  end
  def parse_root(tokens) do
    parse_object(tokens, Document.new(), true)
  end

  def parse_value([]) do
    {[], nil}
  end
  def parse([:open_curly | rest]) do
    parse_object(rest, Document.new())
  end
  def parse([:open_square | rest]) do
    parse_array(rest, [])
  end
  def parse([{:string, str} | rest]) do
    {rest, str}
  end
  def parse([{:unquoted_string, _} = value | rest]) do
    {rest, value}
  end
  def parse([number | rest]) when is_number(number) do
    {rest, number}
  end
  def parse([true | rest]) do
    {rest, true}
  end
  def parse([false | rest]) do
    {rest, false}
  end
  def parse([nil | rest]) do
    {rest, nil}
  end
  def parse(_other) do
    throw {:error, "syntax error"}
  end

  ##
  # loads and parse the content of the `file`
  ##
  defp load_configuration_file(file) do
    with {:ok, conf}   <- load_contents_of_file(file),
         {:ok, ast}    <- Tokenizer.decode(conf),
         {[], result } <- ast
                          |> contact_rule([])
                          |> parse_root() do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  ##
  # loads possible extension in combination with the filename
  ##
  defp load_contents_of_file(file) do
    extenions = case Path.extname(file) do
       ""  -> [".conf", ".json", ".properties"]
       ext -> [ext]
    end

    file = Path.rootname(file)
    case Enum.find(extenions, fn ext -> File.exists?(file <> ext) end) do
      nil -> {:error, :not_found}
      ext -> File.read(file <> ext)
    end
  end

  defp parse_object(tokens, result, is_root \\ false)
  defp parse_object([], result, true) do
    {[], result}
  end
  defp parse_object([:close_curly | rest], result, false) do
    try_merge_object(rest, result)
  end
  defp parse_object([:comma | rest], result, root) do
    parse_object(rest, result, root)
  end
  defp parse_object([:nl | rest], result, root) do
    parse_object(rest, result, root)
  end
  defp parse_object([{:string, key}, :open_curly | rest], result, root) do
    {rest, value} = parse_object(rest, Document.new())
    {rest, doc} = Document.put(result, key, value, rest)
    parse_object(rest, doc, root)
  end
  defp parse_object([{:string, key}, :colon | rest], result, root) do
    {rest, value} = parse(rest)
    {rest, doc} = Document.put(result, key, value, rest)
    parse_object(rest, doc, root)
  end
  defp parse_object([{:unquoted_string, key}, :open_curly | rest], result, root) do
    {rest, value} = parse_object(rest, Document.new())
    {rest, doc} = Document.put(result, key, value, rest)
    parse_object(rest, doc, root)
  end
  defp parse_object([{:unquoted_string, key}, :colon | rest], result, root) do
    {rest, value} = parse(rest)
    {rest, doc} = Document.put(result, key, value, rest)
    parse_object(rest, doc, root)
  end
  defp parse_object([{:unquoted_string, key}, :concat_array | rest], %Document{root: root} = doc, is_root) do
    {rest, value} = parse(rest)
    value = case Document.get_raw(root, key) do
      {:ok, array} when is_list(array) -> array ++ [value]
      _                                -> [value]
    end
    {rest, doc} = Document.put(doc, key, value, rest)
    parse_object(rest, doc, is_root)
  end
  defp parse_object([key, :open_curly | rest], result, root) do
    {rest, value} = parse_object(rest, Document.new())
    {rest, doc} = Document.put(result, to_string(key), value, rest)
    parse_object(rest, doc, root)
  end
  defp parse_object([key, :colon | rest], result, root) do
    {rest, value} = parse(rest)
    {rest, doc} = Document.put(result, to_string(key), value, rest)
    parse_object(rest, doc, root)
  end
  defp parse_object([:include | rest], result, root) do
    parse_include(rest, result, root)
  end
  defp parse_object(_tokens, _result, _root) do
    throw {:error, "syntax error"}
  end

  ##
  # parsing include
  # * required()
  # * file location
  ##
  defp parse_include([:required, :open_round | rest], result, root) do
    {rest, file} = parse_file_location(rest)
    result = case load_configuration_file(file) do
      {:ok, doc} -> Document.merge(result, doc)
      _          -> throw {:error, "file #{file} was not found"}
    end
    parse_required_close(rest, result, root)
  end
  defp parse_include(rest, result, root) do
    {rest, file} = parse_file_location(rest)
    result = case load_configuration_file(file) do
      {:ok, doc} -> Document.merge(result, doc)
      _          -> result
    end
    parse_object(rest, result, root)
  end

  def parse_required_close([:close_round | rest], result, root) do
    parse_object(rest, result, root)
  end
  def parse_required_close(_tokens, _result, _root) do
    throw {:error, "syntax error: ')' required "}
  end

  ##
  # parsing the file location:
  # * file(..)
  # * url(..)
  # * "..."
  # * /path/to/somewhere
  ##
  defp parse_file_location([:file, :open_round, {:string, file}, :close_round | rest]) do
    {rest, file}
  end
  defp parse_file_location([:url, :open_round, {:string, file}, :close_round | rest]) do
    {rest, file}
  end
  defp parse_file_location([{:string, file} | rest]) do
    {rest, file}
  end
  defp parse_file_location([{:unquoted_string, file} | rest]) do
    {rest, file}
  end
  defp parse_file_location(_rest) do
    throw {:error, "syntax error: file location required"}
  end

  def try_merge_object([:open_curly | rest], result) do
    with {rest, other} <- parse_object(rest, Document.new()) do
         {rest, Document.merge(result, other)}
     end
  end
  def try_merge_object([:nl | rest], result) do
    {rest, result}
  end
  def try_merge_object(tokens, result) do
    {tokens, result}
  end

  defp parse_array([:close_square| rest], result) do
    try_concat_array(rest, Enum.reverse(result))
  end
  defp parse_array([:comma, :close_square | rest], result) do
    try_concat_array(rest, Enum.reverse(result))
  end
  defp parse_array([:comma | rest], result) do
    parse_array(rest, result)
  end
  defp parse_array([:nl, :close_square | rest], result) do
    try_concat_array(rest, Enum.reverse(result))
  end
  defp parse_array([:nl | rest], result) do
    parse_array(rest, result)
  end
  defp parse_array(value, result) do
    {rest, value} = parse(value)
    parse_array(rest, [value | result])
  end

  def try_concat_array([:open_square | rest], result) do
    with {rest, other} <- parse_array(rest, []) do
      {rest, result ++ other}
    end
  end
  def try_concat_array([:nl | rest], result) do
    {rest, result}
  end
  def try_concat_array(tokens, result) do
    {tokens, result}
  end

end