# coding: utf-8

class Clex

  def alternation_regex(a)
    a.map { |t| t.gsub(/([*+?|\/\\^])/,'\\\\\1') }.join('|')
  end

  QUADGRAPHS_C99 = ['%:%:']
  TRIGRAPHS_C99 = ['<<=', '>>=', '...']
  DIGRAPHS_C99 = ['++', '--', '&&', '||', '->', '::', '<:', ':>', '<%', '%>', '##']
  '+-\\/%!-<>^|&*='.split('').each { |c| DIGRAPHS_C99 << "#{c}=" }
  MONOGRAPHS_C99 = '[](){}.&*+-~!/%<>^|?:;=,'.split('')
  REGEX_IDENTIFIER_C99 = '[a-zA-Z][a-zA-Z0-9_]*'
  REGEX_INTEGER_C99 = '(?:[1-9][0-9]*|0[0-7]+|0[xX][a-fA-F0-9]+|0)(?:u|U|l|L|ll|LL)?'
  REGEX_FLOAT_C99 = '(?:[0-9]*\.[0-9]+|[0-9]+\.)(?:[eE][+-]?[0-9]+)?[fFlL]?'
  REGEX_HEX_FLOAT_C99 = '0[xX](?:[0-9a-fA-F]*\.[0-9a-fA-F]+|[0-9a-fA-F]+\.)(?:[pP][+-]?[0-9]+)?[fFlL]?'
  KEYWORDS_C99 = %w( auto break case char const continue default do double else enum extern float for goto if inline int long register restrict return short signed sizeof static struct switch typedef union unsigned void volatile while _Bool _Complex _Imaginary )
  UNIQUE_TOKENS_C99 = {}

  KEYWORDS_OBJC2 = KEYWORDS_C99.dup
  KEYWORDS_OBJC2.concat(%w( bycopy byref in inout oneway out self super ))
  DIRECTIVES_OBJC2 = %w( @class @defs @dynamic @encode @end @implementation @interface @private @protected @public @property @protocol @selector @synchronized @synthesize @try @catch @finally @throw )
  a = %w( __cmd __func__ BOOL Class id IMP nil Nil NO NSObject Protocol SEL self super YES )
  h = {}; a.each { |k| h[k] = k.to_sym }; UNIQUE_TOKENS_OBJC2 = h
  
  QUADGRAPHS_JAVA5 = [ '>>>=' ]
  TRIGRAPHS_JAVA5 = [ '>>>', '<<=', '>>=' ]
  DIGRAPHS_JAVA5 = [ '==', '<=', '>=', '!=', '&&', '||',
                     '++', '--', '<<', '>>', '+=', '-=',
                     '*=', '/=', '&=', '|=', '^=', '%=' ]
  MONOGRAPHS_JAVA5 = '(){}[];,.=><!~?:+-*/&|^%'.split('')
  REGEX_IDENTIFIER_JAVA5 = RUBY_VERSION.match(/^1\.8/) ? '[a-zA-Z_$][a-zA-Z0-9_$]*' : '[\p{Alpha}_$][\p{Alnum}_$]*'
  REGEX_INTEGER_JAVA5 = '(?:[1-9][0-9]*|0[0-7]+|0[xX][a-fA-F0-9]+|0)(?:l|L)?'
  REGEX_FLOAT_JAVA5 = '((?:[0-9]*\.[0-9]+|[0-9]+\.)(?:[eE][+-]?[0-9]+)?[fFdD]?|[0-9]+(?:[eE][+-]?[0-9]+)[fFdD]?|[0-9]+(?:[eE][+-]?[0-9]+)?[fFdD])'
  REGEX_HEX_FLOAT_JAVA5 = '0[xX](?:[0-9a-fA-F]*\.[0-9a-fA-F]+|[0-9a-fA-F]+\.?)(?:[pP][+-]?[0-9]+)[fFdD]?'
  KEYWORDS_JAVA5 = %w( abstract assert boolean break byte case catch char class const default do double else enum extends final finally float if goto implements import instanceof int interface long native package private protected public short static strictfp super switch synchronized this throw throws transient try void volatile while )
  UNIQUE_TOKENS_JAVA5 = { 'true' => :true, 'false' => :false, 'null' => :null }
  
  def initialize(language)
    @language = language
    @regex_identifier = REGEX_IDENTIFIER_C99
    @regex_integer = REGEX_INTEGER_C99
    @regex_float = REGEX_FLOAT_C99
    @regex_hex_float = REGEX_HEX_FLOAT_C99
    @punctuators = {}
    @punctuators[4] = QUADGRAPHS_C99
    @punctuators[3] = TRIGRAPHS_C99
    @punctuators[2] = DIGRAPHS_C99
    @punctuators[1] = MONOGRAPHS_C99
    @keywords = KEYWORDS_C99
    @unique_tokens = UNIQUE_TOKENS_C99
    case @language
    when :c, :cpp
    when :objective_c
      @keywords = []
      @keywords.concat(KEYWORDS_OBJC2)
      @keywords.concat(DIRECTIVES_OBJC2)
      @unique_tokens = UNIQUE_TOKENS_OBJC2
    when :java, :csharp
      @punctuators[4] = QUADGRAPHS_JAVA5
      @punctuators[3] = TRIGRAPHS_JAVA5
      @punctuators[2] = DIGRAPHS_JAVA5
      @punctuators[1] = MONOGRAPHS_JAVA5
      @regex_identifier = REGEX_IDENTIFIER_JAVA5
      @regex_integer = REGEX_INTEGER_JAVA5
      @regex_float = REGEX_FLOAT_JAVA5
      @regex_hex_float = REGEX_HEX_FLOAT_JAVA5
      @keywords = KEYWORDS_JAVA5
      @unique_tokens = UNIQUE_TOKENS_JAVA5
    else
      raise "unsupported language: #{@language}"
    end
  end

  def lex_char_c99(input)
    case input
    when /\A([^'\\\n]*')/ # end of char
      return :char, $1, $'
    when /\A([^'\\\n]*\\['"?\\abfnrtv])/ # backslash escape
      old_value = $1
      token, value, rest = lex_char($')
      return token, value, input if [:error, :open].include?(token)
      return token, old_value + value, rest
    when /\A([^'\\\n]*\\[0-7]{1,3})/ # octal escape
      old_value = $1
      token, value, rest = lex_char($')
      return token, value, input if [:error, :open].include?(token)
      return token, old_value + value, rest
    when /\A([^'\\\n]*\\x[0-9a-fA-F])/ # hex escape
      old_value = $1
      token, value, rest = lex_char($')
      return token, value, input if [:error, :open].include?(token)
      return token, old_value + value, rest
    when /\A[^'\\\n]*(?:\\|\n)/ # lex error
      return :error, nil, input
    else # open char
      return :open, nil, input
    end
  end
  private :lex_char_c99
  
  def lex_char_java5(input)
    case input
    when /\A([^\\\n\r]')/ # 'a'
      return :char, $1, $'
    when /\A(\\[btnfr"'\\]')/ # '\n'
      return :char, $1, $'
    when /\A(\\[0-3]?[0-7]?[0-7]')/  # '\042'
      return :char, $1, $'
    when /\A(\\u[0-9a-fA-F]{4}')/ # '\uFFFF'
      return :char, $1, $'
    when /\A../m
      return :error, nil, input
    else
      return :open, nil, input
    end
  end
  private :lex_char_java5
  
  def lex_char(input)
    case @language
    when :java
      lex_char_java5(input)
    else
      lex_char_c99(input)
    end
  end
  private :lex_char
  
  def lex_string(input)
    case input
    when /\A([^"\n\r\\]*")/ # end of string
      return :string, $1, $'
    when /\A([^"\n\r\\]*\\.)/  # escaped character
      old_value = $1
      token, value, rest = lex_string($')
      return token, '"', input if [:error, :open].include?(token)
      return token, old_value + value, rest
    when /\A[^"\n\\]*\n/ # lex error
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
    case input
    when /\A\s*\/\// # single line comment //
      if /\A\s*(\/\/.*?\n)/.match(input)
        return :comment, $1, $'
      else
        return :open, '//', input
      end
    when /\A\s*\/\*/m # multi-line comment /* */
      if /\A\s*(\/\*.*?\*\/)/m.match(input)
        return :comment, $1, $'
      else
        return :open, '/*', input
      end
    when /\A\s*@"/ # objective C string
      if :objective_c == @language
        token, value, rest = lex_string($')
        if :open == token
          return :open, '@"', input
        elsif :error == token
          return :error, nil, input
        else
          return :string, '@"' + value, rest
        end
      else
        return :error, nil, input
      end
    when /\A\s*"/ # double quoted string " "
      token, value, rest = lex_string($')
      if :open == token
        return :open, '"', input
      elsif :error == token
        return :error, nil, input
      else
        return :string, '"' + value, rest
      end
    when /\A\s*'/ # char literal ' '
      token, value, rest = lex_char($')
      if :open == token
        return :open, "'", input
      elsif :error == token
        return :error, nil, input
      else
        return :char, "'" + value, rest
      end
    when /\A\s*(@#{@regex_identifier})/ # objective c directive
      value, rest = $1, $'
      if @keywords.include?(value)
        return :keyword, value, rest
      else
        return :error, nil, input
      end
    when /\A\s*(#{@regex_identifier})/
      value, rest = $1, $'
      if @keywords.include?(value)
        return :keyword, value, rest
      elsif @unique_tokens.has_key?(value)
        return @unique_tokens[value], value, rest
      else
        return :identifier, value, rest
      end
    when /\A\s*(#{@regex_float})/
      return :float, $1, $'
    when /\A\s*(#{@regex_hex_float})/
      return :float, $1, $'
    when /\A\s*(#{@regex_integer})/
      return :integer, $1, $'
    when /\A\s*(\S.*)\z/m
      val, rest = lex_punctuator($1)
      if val
        return :punctuator, val, rest
      else
        return :error, nil, input
      end
    else
      return :end
    end
  end

  def lex_punctuator(input)
    start = [input.size,4].min
    start.downto(1) do |i|
      val = input[0,i]
      if @punctuators[i].include?(val)
        return val, input[i,(input.length-i)]
      end
    end
    return nil
  end
  private :lex_punctuator
  
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
      token, value, new_rest = lex(rest)
      a << [token, value]
      break if [:end, :open, :error].include?(token)
      raise "software errror: infinite loop on input: #{rest}" if new_rest == rest
      rest = new_rest
    end
    a
  end

end
