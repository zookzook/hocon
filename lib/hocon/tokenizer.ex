defmodule Hocon.Tokenizer do

  alias Hocon.Tokens

  def decode(string) do
    data = skip_bom(string)
    tokenize(data, data, 0, Tokens.new())
  end

  def tokenize("", _original, _skip, tokens) do
    {:ok, Enum.reverse(tokens.acc)}
  end

  def tokenize(<<"\n", rest::bits>>, original, skip, tokens) do
    tokenize(rest, original, skip + 1, Tokens.push(tokens, :nl))
  end
  def tokenize(<<char>> <> rest, original, skip, tokens) when char in '\s\t\r\v' do
    tokenize(rest, original, skip + 1, Tokens.push(tokens, :ws))
  end
  def tokenize(<<0x1C>> <> rest, original, skip, tokens) do
    tokenize(rest, original, skip + 1, tokens)
  end
  def tokenize(<<0x1D>> <> rest, original, skip, tokens) do
    tokenize(rest, original, skip + 1, tokens)
  end
  def tokenize(<<0x1E>> <> rest, original, skip, tokens) do
    tokenize(rest, original, skip + 1, tokens)
  end
  def tokenize(<<0x1F>> <> rest, original, skip, tokens) do
    tokenize(rest, original, skip + 1, tokens)
  end
  def tokenize(<<"#", rest::bits>>, original, skip, tokens) do
    skip_comment(rest, original, skip + 1, tokens)
  end
  def tokenize(<<"/", rest::bits>>, original, skip, tokens) do
    case rest do
      <<"/", rest::bits>> -> skip_comment(rest, original, skip + 2, tokens)
      _                   -> tokenize(rest, original, skip + 1, tokens) ## todo error
    end
  end
  def tokenize(<<"${", rest::bits>>, original, skip, tokens) do
    substitutions(rest, original, skip, tokens, 2)
  end
  def tokenize(<<"{", rest::bits>>, original, skip, tokens) do
    tokenize(rest, original, skip + 1, Tokens.push(tokens, :open_curly))
  end
  def tokenize(<<"}", rest::bits>>, original, skip, tokens) do
    tokenize(rest, original, skip + 1, Tokens.push(tokens, :close_curly))
  end
  def tokenize(<<"[", rest::bits>>, original, skip, tokens) do
    tokenize(rest, original, skip + 1, Tokens.push(tokens, :open_square))
  end
  def tokenize(<<",", rest::bits>>, original, skip, tokens) do
    tokenize(rest, original, skip + 1, Tokens.push(tokens, :comma))
  end
  def tokenize(<<"]", rest::bits>>, original, skip, tokens) do
    tokenize(rest, original, skip + 1, Tokens.push(tokens, :close_square))
  end
  def tokenize(<<":", rest::bits>>, original, skip, tokens) do
    tokenize(rest, original, skip + 1, Tokens.push(tokens, :colon))
  end
  def tokenize(<<"=", rest::bits>>, original, skip, tokens) do
    tokenize(rest, original, skip + 1, Tokens.push(tokens, :colon))
  end
  def tokenize(<<"\"", rest::bits>>, original, skip, tokens) do
    multi_line_string_start(rest, original, skip + 1, tokens, 0)
  end
  def tokenize(<<"0", rest::bits>>, original, skip, tokens) do
    number_zero(rest, original, skip, tokens, 1)
  end
  def tokenize(<<char, rest::bits>>, original, skip, tokens) when char in '123456789' do
    number(rest, original, skip, tokens, 1)
  end
  def tokenize(<<"-", rest::bits>>, original, skip, tokens) do
    number_minus(rest, original, skip, tokens)
  end
  def tokenize(string, original, skip, tokens) do
    unquoted_string(string, original, skip, tokens, 0)
  end

  ##
  # check for multi-line strings
  ##
  def multi_line_string_start(<<"\"\"", rest::bits>>, original, skip, tokens, len) do
    multi_line_string(rest, original, skip + 2, tokens, len)
  end
  def multi_line_string_start(string, original, skip, tokens, len) do
    string(string, original, skip, tokens, len)
  end
  def multi_line_string(<<"\"\"\"", rest::bits>>, original, skip, tokens, len) do
    case rest do
      <<"\"", _::bits>> -> multi_line_string_end(rest, original, skip, tokens, len)
      _ ->
        str = String.trim(binary_part(original, skip, len))
        tokenize(rest, original, skip + len + 3, Tokens.push(tokens, {:string, str}))
    end
  end
  def multi_line_string(<<_char::utf8, rest::bits>>, original, skip, tokens, len) do
    multi_line_string(rest, original, skip, tokens, len + 1)
  end

  def multi_line_string_end(<<"\"", rest::bits>>, original, skip, tokens, len) do
    multi_line_string_end(rest, original, skip, tokens, len + 1)
  end
  def multi_line_string_end(<<_char::utf8, _rest::bits>> = string, original, skip, tokens, len) do
    str = String.trim(binary_part(original, skip, len))
    tokenize(string, original, skip + len, Tokens.push(tokens, {:string, str}))
  end
  def multi_line_string_end("", original, skip, tokens, len) do
    str = String.trim(binary_part(original, skip, len))
    tokenize("", original, skip + len, Tokens.push(tokens, {:string, str}))
  end

  def string(<<"\"", rest::bits>>, original, skip, tokens, len) do
    str = binary_part(original, skip, len)
    tokenize(rest, original, skip + len + 1, Tokens.push(tokens, {:string, str}))
  end
  def string(<<_char::utf8, rest::bits>>, original, skip, tokens, len) do
    string(rest, original, skip, tokens, len + 1)
  end

  def unquoted_string(<<"/", rest::bits>> = string, original, skip, tokens, len) do
    case rest do
      <<"/", _rest::bits>> ->
        str = String.trim(binary_part(original, skip, len))
        tokenize(string, original, skip + len, Tokens.push(tokens, {:unquoted_string, str}))
      _ -> unquoted_string(rest, original, skip, tokens, len + 1)
    end
  end
  def unquoted_string(<<char::utf8, rest::bits>>, original, skip, tokens, len) when char in '\s\n\t\r\v' do
    str = String.trim(binary_part(original, skip, len))
    tokenize(<<char::utf8, rest::bits>>, original, skip + len, Tokens.push(tokens, {:unquoted_string, str}))
  end
  def unquoted_string(<<char::utf8, rest::bits>>, original, skip, tokens, len) when char in '$"{}[]:=,+#`^?!@*&\\' do
    str = String.trim(binary_part(original, skip, len))
    tokenize(<<char::utf8, rest::bits>>, original, skip + len, Tokens.push(tokens, {:unquoted_string, str}))
  end
  def unquoted_string(<<"true", rest::bits>>, original, skip, tokens, 0) do
    tokenize(rest, original, skip + 4, Tokens.push(tokens, true))
  end
  def unquoted_string(<<"null", rest::bits>>, original, skip, tokens, 0) do
    tokenize(rest, original, skip + 4, Tokens.push(tokens, nil))
  end
  def unquoted_string(<<"false", rest::bits>>, original, skip, tokens, 0) do
    tokenize(rest, original, skip + 5, Tokens.push(tokens, false))
  end
  def unquoted_string(<<_char::utf8, rest::bits>>, original, skip, tokens, len) do
    unquoted_string(rest, original, skip, tokens, len + 1)
  end
  def unquoted_string("", original, skip, tokens, len) do
    str = String.trim(binary_part(original, skip, len))
    tokenize("", original, skip + len, Tokens.push(tokens, {:unquoted_string, str}))
  end

  def substitutions(<<"}", rest::bits>>, original, skip, tokens, len)  do
    str = String.trim(binary_part(original, skip, len + 1))
    tokenize(rest, original, skip + len + 1, Tokens.push(tokens, {:unquoted_string, str}))
  end
  def substitutions(<<char::utf8, _rest::bits>>, original, skip, _tokens, _len) when char in '\s\n\t\r\v' do
    error(original, skip)
  end
  def substitutions(<<_char::utf8, rest::bits>>, original, skip, tokens, len) do
    substitutions(rest, original, skip, tokens, len + 1)
  end
  def substitutions("", original, skip, _tokens, _len) do
    error(original, skip)
  end

  ##
  # numbers
  ##

  defp number_minus(<<?0, rest::bits>>, original, skip, tokens) do
    number_zero(rest, original, skip, tokens, 2)
  end
  defp number_minus(<<byte, rest::bits>>, original, skip, tokens) when byte in '123456789' do
    number(rest, original, skip, tokens, 2)
  end
  defp number_minus(<<_rest::bits>>, original, skip, _tokens) do
    error(original, skip + 1)
  end

  defp number(<<byte, rest::bits>>, original, skip, tokens, len) when byte in '0123456789' do
    number(rest, original, skip, tokens, len + 1)
  end
  defp number(<<?., rest::bits>>, original, skip, tokens, len) do
    number_frac(rest, original, skip, tokens, len + 1)
  end
  defp number(<<e, rest::bits>>, original, skip, tokens, len) when e in 'eE' do
    prefix = binary_part(original, skip, len)
    number_exp_copy(rest, original, skip + len + 1, tokens, prefix)
  end
  defp number(<<rest::bits>>, original, skip, tokens, len) do
    int = String.to_integer(binary_part(original, skip, len))
    tokenize(rest, original, skip + len, Tokens.push(tokens, int))
  end

  defp number_frac(<<byte, rest::bits>>, original, skip, tokens, len) when byte in '0123456789' do
    number_frac_cont(rest, original, skip, tokens, len + 1)
  end
  defp number_frac(<<_rest::bits>>, original, skip, _tokens, len) do
    error(original, skip + len)
  end

  defp number_frac_cont(<<byte, rest::bits>>, original, skip, tokens, len) when byte in '0123456789' do
    number_frac_cont(rest, original, skip, tokens, len + 1)
  end
  defp number_frac_cont(<<e, rest::bits>>, original, skip, tokens, len) when e in 'eE' do
    number_exp(rest, original, skip, tokens, len + 1)
  end
  defp number_frac_cont(<<rest::bits>>, original, skip, tokens, len) do
    token = binary_part(original, skip, len)
    float = try_parse_float(token, token, skip)
    tokenize(rest, original, skip + len, Tokens.push(tokens, float))
  end

  defp number_exp(<<byte, rest::bits>>, original, skip, tokens, len) when byte in '0123456789' do
    number_exp_cont(rest, original, skip, tokens, len + 1)
  end
  defp number_exp(<<byte, rest::bits>>, original, skip, tokens, len) when byte in '+-' do
    number_exp_sign(rest, original, skip, tokens, len + 1)
  end
  defp number_exp(<<_rest::bits>>, original, skip, _tokens, len) do
    error(original, skip + len)
  end

  defp number_exp_sign(<<byte, rest::bits>>, original, skip, tokens, len) when byte in '0123456789' do
    number_exp_cont(rest, original, skip, tokens, len + 1)
  end
  defp number_exp_sign(<<_rest::bits>>, original, skip, _tokens, len) do
    error(original, skip + len)
  end

  defp number_exp_cont(<<byte, rest::bits>>, original, skip, tokens, len) when byte in '0123456789' do
    number_exp_cont(rest, original, skip, tokens, len + 1)
  end
  defp number_exp_cont(<<rest::bits>>, original, skip, tokens, len) do
    token = binary_part(original, skip, len)
    float = try_parse_float(token, token, skip)
    tokenize(rest, original, skip + len, Tokens.push(tokens, float))
  end

  defp number_exp_copy(<<byte, rest::bits>>, original, skip, tokens, prefix) when byte in '0123456789' do
    number_exp_cont(rest, original, skip, tokens, prefix, 1)
  end
  defp number_exp_copy(<<byte, rest::bits>>, original, skip, tokens, prefix) when byte in '+-' do
    number_exp_sign(rest, original, skip, tokens, prefix, 1)
  end
  defp number_exp_copy(<<_rest::bits>>, original, skip, _tokens, _prefix) do
    error(original, skip)
  end

  defp number_exp_sign(<<byte, rest::bits>>, original, skip, tokens, prefix, len)  when byte in '0123456789' do
    number_exp_cont(rest, original, skip, tokens, prefix, len + 1)
  end
  defp number_exp_sign(<<_rest::bits>>, original, skip, _tokens, _prefix, len) do
    error(original, skip + len)
  end

  defp number_exp_cont(<<byte, rest::bits>>, original, skip, tokens, prefix, len) when byte in '0123456789' do
    number_exp_cont(rest, original, skip, tokens, prefix, len + 1)
  end
  defp number_exp_cont(<<rest::bits>>, original, skip, tokens, prefix, len) do
    suffix       = binary_part(original, skip, len)
    string       = prefix <> ".0e" <> suffix
    prefix_size  = byte_size(prefix)
    initial_skip = skip - prefix_size - 1
    final_skip   = skip + len
    token        = binary_part(original, initial_skip, prefix_size + len + 1)
    float        = try_parse_float(string, token, initial_skip)
    tokenize(rest, original, final_skip, Tokens.push(tokens, float))
  end

  defp number_zero(<<?., rest::bits>>, original, skip, tokens, len) do
    number_frac(rest, original, skip, tokens, len + 1)
  end
  defp number_zero(<<e, rest::bits>>, original, skip, tokens, len) when e in 'eE' do
    number_exp_copy(rest, original, skip + len + 1, tokens, "0")
  end
  defp number_zero(<<"0", rest::bits>>, original, skip, tokens, len) do
    number_zero(rest, original, skip, tokens, len + 1)
  end
  defp number_zero(<<rest::bits>>, original, skip, tokens, len) do
    tokenize(rest, original, skip + len, Tokens.push(tokens, 0))
  end

  ## comment
  defp skip_comment(<<0x0A, rest::bits>>, original, skip, tokens) do
    tokenize(<<0x0A, rest::bits>>, original, skip, tokens)
  end
  defp skip_comment("", _original, _skip, tokens) do
    {:ok, Enum.reverse(tokens.acc)}
  end
  defp skip_comment(<<_char::utf8, rest::bits>>, original, skip, tokens) do
    skip_comment(rest, original, skip + 1, tokens)
  end

  # https://tools.ietf.org/html/rfc7159#section-8.1
  # https://en.wikipedia.org/wiki/Byte_order_mark#UTF-8
  defp skip_bom(<<0xEF, 0xBB, 0xBF>> <> rest) do
    rest
  end

  defp skip_bom(string) do
    string
  end

  defp try_parse_float(string, token, skip) do
    :erlang.binary_to_float(string)
  catch
    :error, :badarg -> token_error(token, skip)
  end

  defp error(<<_rest::bits>>, _original, skip, _stack, _key_decode, _string_decode) do
    throw {:position, skip - 1}
  end

  defp empty_error(_original, skip) do
    throw {:position, skip}
  end

  # @compile {:inline, error: 2, token_error: 2, token_error: 3}
  defp error(_original, skip) do
    throw {:position, skip}
  end

  defp token_error(token, position) do
    throw {:token, token, position}
  end

end
