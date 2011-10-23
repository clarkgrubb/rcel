# coding: utf-8
require 'test/unit'
require File.dirname(__FILE__) + '/clex.rb'

class ClexTest < Test::Unit::TestCase

  def setup
    @c = Clex.new(:c)
    @objc = Clex.new(:objective_c)
    @java = Clex.new(:java)
  end

  # some directives
  def test_objc1
    token, value, rest = @objc.lex(<<EOF)
@try {
  @throw [[NSException alloc] init];
} @catch (NSException e) {
  // do nothing
}
EOF
    assert_equal(:keyword, token)
    assert_equal("@try", value)
  end

  # an objective c string
  def test_objc2
    token, value, rest = @objc.lex('  @"hello" rest')
    assert_equal(:string, token)
    assert_equal('@"hello"', value)
    assert_equal(' rest', rest)
  end

  def test_objc3
    tokens = @objc.stream('@throw;')
    assert_equal(3, tokens.size)
    [ [:keyword, '@throw'], [:punctuator, ';'], [:end, nil]].each_with_index do |p, i|
      expected_token, expected_value = p
      token, value = tokens[i]
      assert_equal(expected_token, token)
      assert_equal(expected_value, value)
    end
  end

  def test_obj4
    token, value, rest = @objc.lex('@throw;')
    assert_equal(:keyword, token)
    assert_equal('@throw', value)
    assert_equal(';', rest)
  end
  
  # simple string
  def test_string1
    token, value, rest = @c.lex(' "hello there" if')
    assert_equal(:string, token)
    assert_equal('"hello there"', value)
    assert_equal(' if', rest)
  end

  # string with escaped doube quote
  def test_string2
    token, value, rest = @c.lex(' "say \\"hello\\"" while')
    assert_equal(:string, token)
    assert_equal('"say \\"hello\\""', value)
    assert_equal(' while', rest)
  end

  # string with escaped backslash
  def test_string3
    token, value, rest = @c.lex('" hello \\\\" for')
    assert_equal(:string, token)
    assert_equal('" hello \\\\"', value)
    assert_equal(' for', rest)
  end

  # open string
  def test_string4
    token, value, rest = @c.lex('" hello there ')
    assert_equal(:open, token)
    assert_equal('"', value)
    assert_equal('" hello there ', rest)
  end

  # malformed string
  def test_string5
    [ "\" hello \n there\"" ].each do |input|
      token, value, rest = @c.lex(input)
      assert_equal(:error, token, "expected token :error for input #{input}")
    end
  end

  # not an actual newline
  def test_string6
    input = '" hello\n"'
    assert_equal(10, input.length)
    token, value, rest = @c.lex(input)
    assert_equal(:string, token)
    assert_equal(input, value)
    assert_equal('', rest)
  end

  # test a string with embeded backslash that is open
  def test_string7
    input = '" hello\n there'
    token, value, rest = @c.lex(input)
    assert_equal(:open, token)
    assert_equal('"', value)
    assert_equal('" hello\n there', rest)
  end
  
  def test_comment1
    input =<<EOS
// single line comment
if (true) {
EOS
    token, value, rest = @c.lex_comment(input)
    assert_equal(:comment, token)
    assert_equal("// single line comment\n", value)
    assert_equal("if (true) {\n", rest)
  end

  def test_comment2
    input =<<EOS
/* multiline comment
   more */
if (true) {
EOS
    token, value, rest = @c.lex_comment(input)
    assert_equal(:comment, token)
    assert_equal("/* multiline comment\n   more */", value)
    assert_equal("\nif (true) {\n", rest)    
  end

  # whitespace before the identifier is removed
  def test_whitespace1
    token, value, rest = @c.lex("     hello there ")
    assert_equal(:identifier, token)
    assert_equal('hello', value)
    assert_equal(' there ', rest)
  end

  # whitespace including a newline before the identifier is removed
  def test_whitespace2
    token, value, rest = @c.lex("  \n  hello there ")
    assert_equal(:identifier, token)
    assert_equal('hello', value)
    assert_equal(' there ', rest)
  end
  
  def test_identifier1
    token, value, rest = @c.lex(" hello3?")
    assert_equal(:identifier, token)
    assert_equal('hello3', value)
    assert_equal('?', rest)
  end

  # simple integer
  def test_integer1
    token, value, rest = @c.lex(" 123x")
    assert_equal(:integer, token)
    assert_equal('123', value)
    assert_equal('x', rest)
  end

  # unsigned suffix
  def test_integer2
    token, value, rest = @c.lex("546ux")
    assert_equal(:integer, token)
    assert_equal('546u', value)
    assert_equal('x', rest)
  end

  # long suffix
  def test_integer3
    token, value, rest = @c.lex("778l9")
    assert_equal(:integer, token)
    assert_equal('778l', value)
    assert_equal('9', rest)
  end

  # octal
  def test_integer4
    token, value, rest = @c.lex("0754")
    assert_equal(:integer, token)
    assert_equal('0754', value)
    assert_equal('', rest)
  end
  
  # bad octal
  def test_integer5
    token, value, rest = @c.lex("089")
    assert_equal(:integer, token)
    assert_equal('0', value)
    assert_equal('89', rest)
  end
    
  # hex lowercase
  def test_integer6
    token, value, rest = @c.lex("0xAAA0F9Z")
    assert_equal(:integer, token)
    assert_equal('0xAAA0F9', value)
    assert_equal('Z', rest)
  end
  
  # hex uppercase
  def test_integer7
    token, value, rest = @c.lex("0Xabcdef0123456789M")
    assert_equal(:integer, token)
    assert_equal('0Xabcdef0123456789', value)
    assert_equal('M', rest)
  end

  # valid trigraphs
  def test_trigraph1
    %w( <<= >>= ).each do |tg|
      input = " #{tg}garbage"
      token, value, rest = @c.lex(input)
      assert_equal(:punctuator, token, "expected token :punctuator for input #{input}")
      assert_equal(tg, value, "expected value #{tg} for input #{input}")
      assert_equal('garbage', rest, "expected rest garbage for input #{input}")
    end
  end

  # invalid trigraphs
  def test_trigraph2
    { '===' => '==', '&^!' => '&' }.each do |tg, expected_value|
      input = "#{tg}garbage"
      token, value, rest = @c.lex(input)
      assert_equal(:punctuator, token, "expected token :punctuator for input #{input}")
      assert_equal(expected_value, value, "expected value #{tg} for input #{input}")
      expected_rest = input[expected_value.length, input.length]
      assert_equal(expected_rest, rest,  "expected rest #{expected_rest} for input #{input}")
    end
  end

  # valid digraphs
  def test_digraph1
    %w( ++ -- == != <= >= += -= *= /= %= |= &= ^= && || ).each do |dg|
      input = " #{dg} foo bar"
      token, value, rest = @c.lex(input)
      assert_equal(:punctuator, token, "expected token :punctuator for input #{input}")
      assert_equal(dg, value, "expected value #{dg} for input #{input}")
      assert_equal(' foo bar', rest, "expected rest garbage for input #{input}")
    end
  end

  # invalid digraphs
  def test_digraph2
    { '&^' => '&', '<!' => '<' }.each do |dg, expected_value|
      input = "#{dg}garbage"
      token, value, rest = @c.lex(input)
      assert_equal(:punctuator, token, "expected token :punctuator for input #{input}")
      assert_equal(expected_value, value, "expected value #{dg} for input #{input}")
      expected_rest = input[expected_value.length, input.length]
      assert_equal(expected_rest, rest,  "expected rest #{expected_rest} for input #{input}")
    end
  end

  def test_float1
    token, value, rest = @c.lex(" 12.3 boot")
    assert_equal(:float, token)
    assert_equal('12.3', value)
    assert_equal(' boot', rest)
  end

  def test_float2
    token, value, rest = @c.lex(" 12. boot")
    assert_equal(:float, token)
    assert_equal('12.', value)
    assert_equal(' boot', rest)    
  end

  def test_float3
    token, value, rest = @c.lex(" .998 boot")
    assert_equal(:float, token)
    assert_equal('.998', value)
    assert_equal(' boot', rest)    
  end

  def test_float4
    token, value, rest = @c.lex(" 10.3e7 boot")
    assert_equal(:float, token)
    assert_equal('10.3e7', value)
    assert_equal(' boot', rest)    
  end

  def test_float4
    token, value, rest = @c.lex(" 10.3e-78 boot")
    assert_equal(:float, token)
    assert_equal('10.3e-78', value)
    assert_equal(' boot', rest)    
  end

  def test_float5
    token, value, rest = @c.lex(" 10.99E+99 boot")
    assert_equal(:float, token)
    assert_equal('10.99E+99', value)
    assert_equal(' boot', rest)    
  end

  def test_float6
    token, value, rest = @c.lex(" 10.9f boot")
    assert_equal(:float, token)
    assert_equal('10.9f', value)
    assert_equal(' boot', rest)    
  end

  # hex float, uppercase
  def test_float7
    token, value, rest = @c.lex(" 0xABCDEF.0123456789 boondocks")
    assert_equal(:float, token)
    assert_equal('0xABCDEF.0123456789', value)
    assert_equal(' boondocks', rest)
  end

  # hex float, lowercase
  def test_float8
    token, value, rest = @c.lex(" 0xabcdef. boondocks")
    assert_equal(:float, token)
    assert_equal('0xabcdef.', value)
    assert_equal(' boondocks', rest)
  end

  # hex float with exponent
  def test_float9
    token, value, rest = @c.lex(" 0xabcdef.123p-17boondocks")
    assert_equal(:float, token)
    assert_equal('0xabcdef.123p-17', value)
    assert_equal(' boondocks', rest)
  end

  # hex float with suffix
  def test_float9
    token, value, rest = @c.lex(" 0xabcdef.123p-17L boondocks")
    assert_equal(:float, token)
    assert_equal('0xabcdef.123p-17L', value)
    assert_equal(' boondocks', rest)
  end

  def test_char1
    token, value, rest = @c.lex("   'c' boot")
    assert_equal(:char, token)
    assert_equal("'c'", value)
    assert_equal(' boot', rest)
  end

  # escaped backslash
  def test_char2
    token, value, rest = @c.lex("   '\\\\' boot")
    assert_equal(:char, token)
    assert_equal("'\\\\'", value)
    assert_equal(' boot', rest)
  end

  # escaped single quote
  def test_char3
    token, value, rest = @c.lex("   '\\'' boot")
    assert_equal(:char, token)
    assert_equal("'\\''", value)
    assert_equal(' boot', rest)    
  end

  # open char
  def test_char4
    token, value, rest = @c.lex("    'blah")
    assert_equal(:open, token)
    assert_equal("'", value)
    assert_equal("    'blah", rest)
  end

  # octal escape
  def test_char5
    { " '\\1' yes" => "'\\1'" , " '\\11' yes" => "'\\11'", " '\\111' yes" => "'\\111'" }.each do |input,expected_value|
      token, value, rest = @c.lex(input)
      assert_equal(:char, token, "expected token :char for input #{input}")
      assert_equal(expected_value, value, "expected value #{expected_value} for input #{input}" )
      assert_equal(" yes", rest)    
    end
  end

  # hex escape
  def test_char6
    { " '\\xA' yes" => "'\\xA'" , " '\\xB' yes" => "'\\xB'", " '\\x7' yes" => "'\\x7'" }.each do |input,expected_value|
      token, value, rest = @c.lex(input)
      assert_equal(:char, token, "expected token :char for input #{input}")
      assert_equal(expected_value, value, "expected value #{expected_value} for input #{input}" )
      assert_equal(" yes", rest)    
    end
  end

  # malformed char literals
  def test_char7
    [ " '\\xZ' bad", " 'a\n' bad", " 'a\\ ' bad" ].each do |input|
      token, value, rest = @c.lex(input)
      assert_equal(:error, token, "expected token :error for input #{input}")
    end
  end

  # test a character with embeded backslash that is open
  def test_char8
    input = "' hello\\n there"
    token, value, rest = @c.lex(input)
    assert_equal(:open, token)
    assert_equal("'", value)
    assert_equal("' hello\\n there", rest)
  end
  
  def test_java_float1
    [ "12.3", "45e7", "123f" ].each do |input|
      token, value, rest = @java.lex(input)
      assert_equal(:float, token)
      assert_equal(input, value)
      assert_equal('', rest)
    end
  end

  def test_java_float2
    ["0x1abcdef.012p10", "0X11P-5" ].each do |input|
      token, value, rest = @java.lex(input)
      assert_equal(:float, token)
      assert_equal(input, value)
      assert_equal('', rest)
    end
  end

  def test_java_identifier1
    ["_hello", "$hello", "hello_", "hello$", "a1234", "λ1234" ].each do |input|
      token, value, rest = @java.lex(input)
      assert_equal(:identifier, token, "expected token :identifier for input #{input}")
      assert_equal(input, value, "expected value #{input} for input #{input}")
      assert_equal('', rest)
    end
  end

  def test_java_keyword1
    [ 'abstract', 'interface', 'class', 'throw', 'public' ].each do |input|
      token, value, rest = @java.lex(input)
      assert_equal(:keyword, token)
      assert_equal(input, value)
      assert_equal('', rest)
    end
  end

  def test_java_unique_tokens1
    { 'true' => :true, 'false' => :false , 'null' => :null }.each do |input, expected_token|
      token, value, rest = @java.lex(input)
      assert_equal(expected_token, token)
      assert_equal(input, value)
      assert_equal('', rest)
    end
  end

  # regular char literal
  def test_java_char1
    token, value, rest = @java.lex("'a' and stuff")
    assert_equal(:char, token)
    assert_equal("'a'", value)
    assert_equal(' and stuff', rest)
  end

  # backslash escapes
  def test_java_char2
    [ 'b', 't', 'n', 'f', 'r', "'", '"', '\\' ].each do |c|
      input = "'\\#{c}' more"
      token, value, rest = @java.lex(input)
      assert_equal(:char, token, "expected token :char for input #{input}")
      assert_equal("'\\#{c}'", value, "expected value '\\#{c}' for input #{input}")
      assert_equal(' more', rest)
    end
  end

  # octal escapes
  def test_java_char3
    (0...8).each do |i|
      input = "'\\%o'" % i
      token, value, rest = @java.lex(input)
      assert_equal(:char, token, "expected token :char for input #{input}")
      assert_equal(input, value)
      assert_equal('', rest)
    end
    (0...64).each do |i|
      input = "'\\%02o'" % i
      token, value, rest = @java.lex(input)
      assert_equal(:char, token, "expected token :char for input #{input}")
      assert_equal(input, value)
      assert_equal('', rest)
    end
    (0...256).each do |i|
      input = "'\\%03o'" % i
      token, value, rest = @java.lex(input)
      assert_equal(:char, token, "expected token :char for input #{input}")
      assert_equal(input, value)
      assert_equal('', rest)
    end
  end

  # hex escapes
  def test_java_char4
    %w( x X ).each do |format_specifier|
      (0...(2**16)).each do |i|
        input = "'\\u%04#{format_specifier}'" % i
        token, value, rest = @java.lex(input)
        assert_equal(:char, token, "expected token :char for input #{input}")
        assert_equal(input, value)
        assert_equal('', rest)
      end
    end
  end

  # error: invalid backslash
  def test_java_char5
    token, value, rest = @java.lex("'\\x'")
    assert_equal(:error, token)
  end

  # error: newline 
  def test_java_char6
    token, value, rest = @java.lex("'\n'")
    assert_equal(:error, token)
  end

  # error: not terminated
  def test_java_char7
    token, value, rest = @java.lex("'aaa")
    assert_equal(:error, token)
  end

  # too long
  def test_java_char8
    token, value, rest = @java.lex("'aa'")
    assert_equal(:error, token)
  end

  # open
  def test_java_char9
    token, value, rest = @java.lex("'a")
    assert_equal(:open, token)
  end

  # octal out of range
  def test_java_char10
    token, value, rest = @java.lex("'\\09'")
    assert_equal(:error, token)
  end

  # hex too short
  def test_java_char11
    token, value, rest = @java.lex("'\\uFFF'")
    assert_equal(:error, token)
  end

  # bad hex
  def test_java_char12
    token, value, rest = @java.lex("'\\uGH07")
    assert_equal(:error, token)
  end
  
end
