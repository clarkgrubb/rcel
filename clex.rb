
class Clex

  REGEX_IDENTIFIER = '[a-zA-Z][a-zA-Z0-9_]*'
  REGEX_TRIGRAPH = '<<=|>>='
  REGEX_DIGRAPH = '\\+\\+|--|[+-\\/%!=<>^|&]=|\\*=|&&|\\|\\||->|::'
  REGEX_INTEGER = '(?:[1-9][0-9]*|0[0-7]+|0[xX][a-fA-F0-9]+|0)(?:u|U|l|L|ll|LL)?'
  REGEX_FLOAT = '(?:[0-9]*\.[0-9]+|[0-9]+\.)(?:[eE][+-]?[0-9]+)?[fFlL]?'
  REGEX_HEX_FLOAT = '0[xX](?:[0-9a-fA-F]*\.[0-9a-fA-F]+|[0-9a-fA-F]+\.)(?:[pP][+-]?[0-9]+)?[fFlL]?'
  
  KEYWORDS = %w( auto break case char const continue default do double else enum extern float for goto if inline int long register restrict return short signed sizeof static struct switch typedef union unsigned void volatile while _Bool _Complex _Imaginary )
  
  def initialize(language)
    @regex_identifier = REGEX_IDENTIFIER
    @regex_integer = REGEX_INTEGER
    @regex_float = REGEX_FLOAT
    @regex_hex_float = REGEX_HEX_FLOAT
    @regex_trigraph = REGEX_TRIGRAPH
    @regex_digraph = REGEX_DIGRAPH
    @keywords = KEYWORDS
    case language
    when :c
    when :cpp
    when :objective_c
    when :java
    when :csharp
    else
      raise "unsupported language: #{language}"
    end
  end

  def lex_char(input)
    if /\A([^'\\\n]*')/.match(input) # end of char
      return :char, $1, $'
    elsif /\A([^'\\\n]*\\['"?\\abfnrtv])/.match(input) # backslash escape
      old_value = $1
      token, value, rest = lex_char($')
      return token, value, input if [:error, :open].include?(token)
      return token, old_value + value, rest
    elsif /\A([^'\\\n]*\\[0-7]{1,3})/.match(input) # octal escape
      old_value = $1
      token, value, rest = lex_char($')
      return token, value, input if [:error, :open].include?(token)
      return token, old_value + value, rest
    elsif /\A([^'\\\n]*\\x[0-9a-fA-F])/.match(input) # hex escape
      old_value = $1
      token, value, rest = lex_char($')
      return token, value, input if [:error, :open].include?(token)
      return token, old_value + value, rest
    elsif /\A[^'\\\n]*(?:\\|\n)/.match(input) # lex error
      return :error, nil, input
    else # open char
      return :open, nil, input
    end
  end
  private :lex_char
  
  def lex_string(input)
    if /\A([^"\n\\]*")/.match(input) # end of string
      return :string, $1, $'
    elsif /\A([^"\n\\]*\\.)/.match(input)  # escaped character
      old_value = $1
      token, value, rest = lex_string($')
      return token, old_value + value, rest
    elsif /\A[^"\n\\]*\n/.match(input) # lex error
      return :error, nil, input
    else # open string
      return :open, nil, input
    end
  end
  private :lex_string
  
  # works the same as lex, except that comments are returned
  # with token type :comment
  #
  def lex_comment(input)
    if /\A\s*\/\//.match(input) # single line comment //
      if /\A\s*(\/\/.*?\n)/.match(input)
        return :comment, $1, $'
      else
        return :open, '//', input
      end
    elsif /\A\s*\/\*/m.match(input) # multi-line comment /* */
      if /\A\s*(\/\*.*?\*\/)/m.match(input)
        return :comment, $1, $'
      else
        return :open, '/*', input
      end
    elsif /\A\s*"/.match(input) # double quoted string " "
      token, value, rest = lex_string($')
      if :open == token
        return :open, '"', input
      elsif :error == token
        return :error, nil, input
      else
        return :string, '"' + value, rest
      end
    elsif /\A\s*'/.match(input) # char literal ' '
      token, value, rest = lex_char($')
      if :open == token
        return :open, "'", input
      elsif :error == token
        return :error, nil, input
      else
        return :char, "'" + value, rest
      end
    elsif /\A\s*(#{@regex_identifier})/.match(input) # identifier
      value, rest = $1, $'
      if @keywords.include?(value)
        return :keyword, value, rest
      else
        return :identifier, value, rest
      end
    elsif /\A\s*(#{@regex_float})/.match(input) # float
      return :float, $1, $'
    elsif /\A\s*(#{@regex_hex_float})/.match(input) # hex float
      return :float, $1, $'
    elsif /\A\s*(#{@regex_integer})/.match(input) # integer
      return :integer, $1, $'
    elsif /\A\s*(#{@regex_trigraph})/.match(input) # trigraphs
      return :punctuator, $1, $'
    elsif /\A\s*(#{@regex_digraph})/.match(input) # digraphs
      return :punctuator, $1, $'
    elsif /\A\s*(\S)/.match(input) # any other single character token
      return :punctuator, $1, $'
    else
      return :end, 
    end
  end
  
  # Returns three args: token_type, value, rest
  #
  # token types:
  #  :string
  #  :identifier
  #  :keyword
  #  :integer
  #  :float
  #  :char
  #  :punctuator
  #  :end   (end of well formed stream)
  #  :open  (open string or char literal; more input could make stream well formed)
  #  :error (malformed string or char literal; more input won't help)
  #
  # When the 1st argument is :end, :open, or :error, the 2nd and 3rd
  # arguments will be as follows:
  #
  #  1ST ARG      2ND ARG              3RD ARG
  #  :end         nil                  nil
  #  :open        //,  /*, ", or '     input
  #  :error       nil                  input
  #
  def lex(input)
    loop do
      token, value, rest = lex_comment(input)
      if :comment == token
        raise "infinite loop on input: #{input}" if input == rest
        input = rest
      else
        return token, value, rest
      end
    end
  end

  # convert the input to an array of token_name and token_value pairs.
  # the last pair will have a first value of either :open, :end, or :error; the
  # second value will be the opening delimiter, nil, or nil
  def stream(input)
    rest = input
    a = []
    loop do
      token, value, rest = lex(rest)
      a << [token, value]
      break if [:end, :open].include?(token)
    end
    a
  end

end
