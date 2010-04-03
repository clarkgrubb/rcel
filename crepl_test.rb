require 'crepl'
require 'stringio'
require 'test/unit'
require 'fileutils'
require 'pp'

class Test::Unit::TestCase

  LANGUAGES = {
    :c => 'c',
    :java => 'java',
    :csharp => 'c#',
    :cpp => 'c++',
    :objc => 'objective-c'
  }
  DIRECTORIES = {
    :c => 'c-test',
    :java  => 'java-test',
    :csharp => 'csharp-test',
    :cpp => 'cpp-test',
    :objc => 'objective-c-test'
  }
  
  def setup
    @repl = {}
    LANGUAGES.each do |key, lang|
      FileUtils.rm_rf(DIRECTORIES[key])
      @repl[key] = Crepl.new([lang, DIRECTORIES[key]])
    end
    @c = @repl[:c]
    @java = @repl[:java]
    @csharp = @repl[:csharp]
    @cpp = @repl[:cpp]
    @objc = @repl[:objc]
  end

  def eval_print(repl, line)
    input = StringIO.new(line)
    output = StringIO.new
    repl.repl(:input=>input, :output=>output)
    output.rewind
    lines_out = output.readlines.map { |l| l.strip }
    lines_out.reject! { |l| l.empty? }
    lines_out
  end
  
  def test_c1
    lines = eval_print(@c, 'printf("hello world\\n");')
    assert_equal(1, lines.size)
    assert_equal('hello world', lines[0])
  end

  # test #include and #class
  def test_c2
    lines = eval_print(@c, <<'EOF')
#include <stdarg.h>
#class
int add(int first, ...) {
  va_list ap;
  va_start(ap, first);
  int second = va_arg(ap, int);
  va_end(ap);
  return first + second;
}
pf("%d\n", add(3,7));
EOF
    assert_equal(1, lines.size);
    assert_equal(10, lines[0].to_i);
  end
  
  def test_java1
    lines = eval_print(@java, 'System.out.println("hello world");')
    assert_equal(1, lines.size)
    assert_equal('hello world', lines[0])
  end

  def test_csharp1
    lines = eval_print(@csharp, 'System.Console.WriteLine("hello world");')
    assert_equal(1, lines.size)
    assert_equal('hello world', lines[0])
  end

  def test_cpp1
    lines = eval_print(@cpp, 'cout << "hello world" << endl;')
    assert_equal(1, lines.size)
    assert_equal('hello world', lines[0])
  end

  def test_objc1
    lines = eval_print(@objc, 'printf("hello world\\n");')
    assert_equal(1, lines.size)
    assert_equal('hello world', lines[0])
  end

  # test a java enum, which must be placed outside the Main method
  # but inside the class definition.
  def test_java2
    lines = eval_print(@java, <<EOF)
public enum DayOfWeek { MON, TUE, WED, THU, FRI, SAT, SUN };
pf("Day of Week: %s", DayOfWeek.TUE);
EOF
    assert_equal(1, lines.size)
    assert_equal("Day of Week: TUE", lines[0])
  end

  def test_arg1
    lines = eval_print(@c, <<EOF)
#arg hello
p(argv[1]);
EOF
    assert_equal(1, lines.size)
    assert_equal("hello", lines[0])
  end

  def test_arg2
    lines = eval_print(@c, <<EOF)
#arg hello there
pf("%d", argc);
p(argv[1]);
p(argv[2]);
  end
EOF
    assert_equal(3, lines.size)
    ["3", "hello", "there" ].each_with_index do |line, i|
      assert_equal(line, lines[i], "expected line #{i+1} to be #{line}")
    end
  end
end
