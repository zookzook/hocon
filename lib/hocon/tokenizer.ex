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
  def tokenize(<<"//", rest::bits>> = string, original, skip, tokens) do
    skip_comment(rest, original, skip + 2, tokens)
  end
  def tokenize(<<"+=", rest::bits>>, original, skip, tokens) do
    tokenize(rest, original, skip + 2, Tokens.push(tokens, :concat_array))
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
  def tokenize(<<"(", rest::bits>>, original, skip, tokens) do
    tokenize(rest, original, skip + 1, Tokens.push(tokens, :open_round))
  end
  def tokenize(<<")", rest::bits>>, original, skip, tokens) do
    tokenize(rest, original, skip + 1, Tokens.push(tokens, :close_round))
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
  def tokenize(<<"+", rest::bits>>, original, skip, tokens) do
    number_minus(rest, original, skip, tokens)
  end
  def tokenize(<<char::utf8, _rest::bits>>, original, skip, _tokens) when char in '$"{}[]:=,+#`^?!@*&\\' do
    error(original, skip)
  end
  def tokenize(string, original, skip, tokens) do
    unquoted_string(string, original, skip, tokens, 0)
  end

  ##
  # check for multi-line strings
  # fortunately unicode escapes are not interpreted in triple-quoted strings.
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
  def multi_line_string(<<char::utf8, rest::bits>>, original, skip, tokens, len) when char < 0x80  do
    multi_line_string(rest, original, skip, tokens, len + 1)
  end
  def multi_line_string(<<char::utf8, rest::bits>>, original, skip, tokens, len) when char < 0x800  do
    multi_line_string(rest, original, skip, tokens, len + 2)
  end
  def multi_line_string(<<char::utf8, rest::bits>>, original, skip, tokens, len) when char < 0x10000  do
    multi_line_string(rest, original, skip, tokens, len + 3)
  end
  def multi_line_string(<<_char::utf8, rest::bits>>, original, skip, tokens, len)  do
    multi_line_string(rest, original, skip, tokens, len + 4)
  end

  def multi_line_string_end(<<"\"", rest::bits>>, original, skip, tokens, len) do
    multi_line_string_end(rest, original, skip, tokens, len + 1)
  end
  def multi_line_string_end(<<_char::utf8, _rest::bits>> = string, original, skip, tokens, len) do
    str = String.trim(binary_part(original, skip, len))
    tokenize(string, original, skip + len + 3, Tokens.push(tokens, {:string, str}))
  end
  def multi_line_string_end("", original, skip, tokens, len) do
    str = String.trim(binary_part(original, skip, len))
    tokenize("", original, skip + len, Tokens.push(tokens, {:string, str}))
  end

  def string(<<"\\", rest::bits>>, original, skip, tokens, len) do
    str = binary_part(original, skip, len)
    escape(rest, original, skip + len, tokens, str)
  end
  def string(<<"\"", rest::bits>>, original, skip, tokens, len) do
    str = binary_part(original, skip, len)
    tokenize(rest, original, skip + len + 1, Tokens.push(tokens, {:string, str}))
  end
  def string(<<char::utf8, rest::bits>>, original, skip, tokens, len) when char < 0x80  do
    string(rest, original, skip, tokens, len + 1)
  end
  def string(<<char::utf8, rest::bits>>, original, skip, tokens, len) when char < 0x800  do
    string(rest, original, skip, tokens, len + 2)
  end
  def string(<<char::utf8, rest::bits>>, original, skip, tokens, len) when char < 0x10000  do
    string(rest, original, skip, tokens, len + 3)
  end
  def string(<<_char::utf8, rest::bits>>, original, skip, tokens, len)  do
    string(rest, original, skip, tokens, len + 4)
  end

  def string(<<"\\", rest::bits>>, original, skip, tokens, acc, len) do
    str = binary_part(original, skip, len)
    escape(rest, original, skip + len, tokens, [acc | str])
  end

  def string(<<"\"", rest::bits>>, original, skip, tokens, acc, len) do
    last = binary_part(original, skip, len)
    str  = IO.iodata_to_binary([acc | last])
    tokenize(rest, original, skip + len + 1, Tokens.push(tokens, {:string, str}))
  end
  def string(<<char::utf8, rest::bits>>, original, skip, tokens, acc, len) when char < 0x80  do
    string(rest, original, skip, tokens, acc, len + 1)
  end
  def string(<<char::utf8, rest::bits>>, original, skip, tokens, acc, len) when char < 0x800  do
    string(rest, original, skip, tokens, acc, len + 2)
  end
  def string(<<char::utf8, rest::bits>>, original, skip, tokens, acc, len) when char < 0x10000  do
    string(rest, original, skip, tokens, acc, len + 3)
  end
  def string(<<_char::utf8, rest::bits>>, original, skip, tokens, acc, len)  do
    string(rest, original, skip, tokens, acc, len + 4)
  end
  def string(<<_rest::bits>>, original, skip, _tokens, _acc, _len) do
    empty_error(original, skip)
  end

  defp process_unquoted_string("include", tokens) do
    Tokens.push(tokens, :include)
  end
  defp process_unquoted_string("required", tokens) do
    Tokens.push(tokens, :required)
  end
  defp process_unquoted_string("file", tokens) do
    Tokens.push(tokens, :file)
  end
  defp process_unquoted_string("url", tokens) do
    Tokens.push(tokens, :url)
  end
  defp process_unquoted_string(str, tokens) do
    Tokens.push(tokens, {:unquoted_string, str})
  end

  def unquoted_string(<<"/", rest::bits>> = string, original, skip, tokens, len) do
    case rest do
      <<"/", _rest::bits>> ->
        str = String.trim(binary_part(original, skip, len))
        tokenize(string, original, skip + len, process_unquoted_string(str, tokens))
      _ -> unquoted_string(rest, original, skip, tokens, len + 1)
    end
  end
  def unquoted_string(<<char::utf8, rest::bits>>, original, skip, tokens, len) when char in '\s\n\t\r\v' do
    str = String.trim(binary_part(original, skip, len))
    tokenize(<<char::utf8, rest::bits>>, original, skip + len, process_unquoted_string(str, tokens))
  end
  def unquoted_string(<<char::utf8, rest::bits>>, original, skip, tokens, len) when char in '()$"{}[]:=,+#`^?!@*&\\' do
    str = String.trim(binary_part(original, skip, len))
    tokenize(<<char::utf8, rest::bits>>, original, skip + len, process_unquoted_string(str, tokens))
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
    tokenize("", original, skip + len, process_unquoted_string(str, tokens))
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
  # from : https://github.com/michalmuskala/jason/blob/master/lib/decoder.ex
  # with some modifications
  ##

  defp escape(<<"b", rest::bits>>, original, skip, tokens, acc) do
    string(rest, original, skip + 2, tokens, [acc | '\b'], 0)
  end
  defp escape(<<"t", rest::bits>>, original, skip, tokens, acc) do
    string(rest, original, skip + 2, tokens, [acc | '\t'], 0)
  end
  defp escape(<<"n", rest::bits>>, original, skip, tokens, acc) do
    string(rest, original, skip + 2, tokens, [acc | '\n'], 0)
  end
  defp escape(<<"f", rest::bits>>, original, skip, tokens, acc) do
    string(rest, original, skip + 2, tokens, [acc | '\f'], 0)
  end
  defp escape(<<"r", rest::bits>>, original, skip, tokens, acc) do
    string(rest, original, skip + 2, tokens, [acc | '\r'], 0)
  end
  defp escape(<<"\"", rest::bits>>, original, skip, tokens, acc) do
    string(rest, original, skip + 2, tokens, [acc | '"'], 0)
  end
  defp escape(<<"/", rest::bits>>, original, skip, tokens, acc) do
    string(rest, original, skip + 2, tokens, [acc | '/'], 0)
  end
  defp escape(<<"\\", rest::bits>>, original, skip, tokens, acc) do
    string(rest, original, skip + 2, tokens, [acc | '\\'], 0)
  end
  defp escape(<<"u", rest::bits>>, original, skip, tokens, acc) do
    escapeu(rest, original, skip, tokens, acc)
  end
  defp escape(<<_, _rest::bits>>, original, skip, _tokens, _acc) do
    error(original, skip + 1)
  end
  defp escape(<<_rest::bits>>, original, skip, _tokens, _acc) do
    empty_error(original, skip)
  end

  # coveralls-ignore-start

  defmodule Unescape do
    @moduledoc false

    import Bitwise

    @digits Enum.concat([?0..?9, ?A..?F, ?a..?f])

    def unicode_escapes(chars1 \\ @digits, chars2 \\ @digits) do
      for char1 <- chars1, char2 <- chars2 do
        {(char1 <<< 8) + char2, integer8(char1, char2)}
      end
    end

    defp integer8(char1, char2) do
      (integer4(char1) <<< 4) + integer4(char2)
    end

    defp integer4(char) when char in ?0..?9, do: char - ?0
    defp integer4(char) when char in ?A..?F, do: char - ?A + 10
    defp integer4(char) when char in ?a..?f, do: char - ?a + 10

    defp token_error_clause(original, skip, len) do
      quote do
        _ ->
          token_error(unquote_splicing([original, skip, len]))
      end
    end

    defmacro escapeu_first(int, last, rest, original, skip, tokens, acc) do
      clauses = escapeu_first_clauses(last, rest, original, skip, tokens, acc)
      quote location: :keep do
        case unquote(int) do
          unquote(clauses ++ token_error_clause(original, skip, 6))
        end
      end
    end

    defp escapeu_first_clauses(last, rest, original, skip, tokens, acc) do
      for {int, first} <- unicode_escapes(),
          not (first in 0xDC..0xDF) do
        escapeu_first_clause(int, first, last, rest, original, skip, tokens, acc)
      end
    end

    defp escapeu_first_clause(int, first, last, rest, original, skip, tokens, acc)
         when first in 0xD8..0xDB do
      hi =
        quote bind_quoted: [first: first, last: last] do
          0x10000 + ((((first &&& 0x03) <<< 8) + last) <<< 10)
        end
      args = [rest, original, skip, tokens, acc, hi]
      [clause] =
        quote location: :keep do
          unquote(int) -> escape_surrogate(unquote_splicing(args))
        end
      clause
    end

    defp escapeu_first_clause(int, first, last, rest, original, skip, tokens, acc)
         when first <= 0x00 do
      skip = quote do: (unquote(skip) + 6)
      acc =
        quote bind_quoted: [acc: acc, first: first, last: last] do
          if last <= 0x7F do
            # 0?????
            [acc, last]
          else
            # 110xxxx??  10?????
            byte1 = ((0b110 <<< 5) + (first <<< 2)) + (last >>> 6)
            byte2 = (0b10 <<< 6) + (last &&& 0b111111)
            [acc, byte1, byte2]
          end
        end
      args = [rest, original, skip, tokens, acc, 0]
      [clause] =
        quote location: :keep do
          unquote(int) -> string(unquote_splicing(args))
        end
      clause
    end

    defp escapeu_first_clause(int, first, last, rest, original, skip, tokens, acc)
         when first <= 0x07 do
      skip = quote do: (unquote(skip) + 6)
      acc =
        quote bind_quoted: [acc: acc, first: first, last: last] do
          # 110xxx??  10??????
          byte1 = ((0b110 <<< 5) + (first <<< 2)) + (last >>> 6)
          byte2 = (0b10 <<< 6) + (last &&& 0b111111)
          [acc, byte1, byte2]
        end
      args = [rest, original, skip, tokens, acc, 0]
      [clause] =
        quote location: :keep do
          unquote(int) -> string(unquote_splicing(args))
        end
      clause
    end

    defp escapeu_first_clause(int, first, last, rest, original, skip, tokens, acc)
         when first <= 0xFF do
      skip = quote do: (unquote(skip) + 6)
      acc =
        quote bind_quoted: [acc: acc, first: first, last: last] do
          # 1110xxxx  10xxxx??  10??????
          byte1 = (0b1110 <<< 4) + (first >>> 4)
          byte2 = ((0b10 <<< 6) + ((first &&& 0b1111) <<< 2)) + (last >>> 6)
          byte3 = (0b10 <<< 6) + (last &&& 0b111111)
          [acc, byte1, byte2, byte3]
        end
      args = [rest, original, skip, tokens, acc, 0]
      [clause] =
        quote location: :keep do
          unquote(int) -> string(unquote_splicing(args))
        end
      clause
    end

    defmacro escapeu_last(int, original, skip) do
      clauses = escapeu_last_clauses()
      quote location: :keep do
        case unquote(int) do
          unquote(clauses ++ token_error_clause(original, skip, 6))
        end
      end
    end

    defp escapeu_last_clauses() do
      for {int, last} <- unicode_escapes() do
        [clause] =
          quote do
            unquote(int) -> unquote(last)
          end
        clause
      end
    end

    defmacro escapeu_surrogate(int, last, rest, original, skip, tokens, acc,
               hi) do
      clauses = escapeu_surrogate_clauses(last, rest, original, skip, tokens, acc, hi)
      quote location: :keep do
        case unquote(int) do
          unquote(clauses ++ token_error_clause(original, skip, 12))
        end
      end
    end

    defp escapeu_surrogate_clauses(last, rest, original, skip, tokens, acc, hi) do
      digits1 = 'Dd'
      digits2 = Stream.concat([?C..?F, ?c..?f])
      for {int, first} <- unicode_escapes(digits1, digits2) do
        escapeu_surrogate_clause(int, first, last, rest, original, skip, tokens, acc, hi)
      end
    end

    defp escapeu_surrogate_clause(int, first, last, rest, original, skip, tokens, acc, hi) do
      skip = quote do: unquote(skip) + 12
      acc =
        quote bind_quoted: [acc: acc, first: first, last: last, hi: hi] do
          lo = ((first &&& 0x03) <<< 8) + last
          [acc | <<(hi + lo)::utf8>>]
        end
      args = [rest, original, skip, tokens, acc, 0]
      [clause] =
        quote do
          unquote(int) ->
            string(unquote_splicing(args))
        end
      clause
    end
  end

  # coveralls-ignore-stop

  defp escapeu(<<int1::16, int2::16, rest::bits>>, original, skip, tokens, acc) do
    require Unescape
    last = escapeu_last(int2, original, skip)
    Unescape.escapeu_first(int1, last, rest, original, skip, tokens, acc)
  end
  defp escapeu(<<_rest::bits>>, original, skip, _tokens, _acc) do
    empty_error(original, skip)
  end

  # @compile {:inline, escapeu_last: 3}

  defp escapeu_last(int, original, skip) do
    require Unescape
    Unescape.escapeu_last(int, original, skip)
  end

  defp escape_surrogate(<<?\\, ?u, int1::16, int2::16, rest::bits>>, original, skip, tokens, acc, hi) do
    require Unescape
    last = escapeu_last(int2, original, skip + 6)
    Unescape.escapeu_surrogate(int1, last, rest, original, skip, tokens, acc, hi)
  end
  defp escape_surrogate(<<_rest::bits>>, original, skip, _tokens, _acc, _hi) do
    error(original, skip + 6)
  end

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

  defp error(_original, skip) do
    throw {:position, skip}
  end

  defp token_error(token, position) do
    throw {:token, token, position}
  end

  defp token_error(token, position, len) do
    throw {:token, binary_part(token, position, len), position}
  end

  defp empty_error(_original, skip) do
    throw {:position, skip}
  end

end
