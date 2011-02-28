require 'crepl'
require 'stringio'
require 'test/unit'
require 'fileutils'
require 'pp'
require 'tempfile'

class Test1 < Test::Unit::TestCase

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
  ALTERNATE_DIRECTORY = 'alt-test'
  
  def setup
    @repl = {}
    LANGUAGES.each do |key, lang|
      FileUtils.rm_rf(DIRECTORIES[key])
      @repl[key] = Crepl.new([lang, DIRECTORIES[key]], :test=>true)
    end
    FileUtils.rm_rf(ALTERNATE_DIRECTORY)
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

  def make_file(contents)
    f = Tempfile.new('mkf')
    f.write(contents)
    f.flush
    f
  end

  # simple test of C
  def test_c01
    lines = eval_print(@c, 'printf("hello world\\n");')
    assert_equal(1, lines.size)
    assert_equal('hello world', lines[0])
  end

  # test #include and #class in C
  def test_c02
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
printf("%d\n", add(3,7));
EOF
    assert_equal(1, lines.size);
    assert_equal(10, lines[0].to_i);
  end

  # test p shortcut in C
  def test_c03
    ENV['HOME'] = '/Users/cgrubb'
    lines = eval_print(@c, <<'EOF')
#include <stdlib.h>
puts(getenv("HOME"));
EOF
    assert_equal(1, lines.size)
    assert_equal('/Users/cgrubb', lines[0])
  end

  # test library command in C
  def test_c04
    source = make_file(<<'EOF')
#include "foo.h"
#include <stdio.h>
void say_hello(char *name) {
  printf("Hello, %s\n", name);
}
EOF
    header = make_file(<<'EOF')
void say_hello(char *);
EOF
    lines = eval_print(@c, <<"EOF")
#lib foo #{source.path} #{header.path}
say_hello("Hank");
EOF
    assert_equal(1, lines.size)
    assert_equal("Hello, Hank", lines[0])
  end

  # test arguments command in C
  def test_c05
    lines = eval_print(@c, <<'EOF')
#arguments hello world
printf("%s %s", argv[1], argv[2]);
EOF
    assert_equal(1, lines.size)
    assert_equal("hello world", lines[0])
  end
  
  # test debug in C
  def test_c06
    lines = eval_print(@c, <<'EOF')
#debug
printf("hello there");
EOF
    assert_equal(2, lines.size)
    assert_match(/compile_executable/, lines[0])
    assert_equal("hello there", lines[1])
  end

  # test dir command
  def test_c07
    lines = eval_print(@c, <<"EOF")
#dir #{ALTERNATE_DIRECTORY}
printf("does it work");
EOF
    assert_equal(1, lines.size)
    assert_equal("does it work", lines[0])
    assert(File.exists?("#{ALTERNATE_DIRECTORY}/main.c"))
  end

  # test header command in C
  def test_c08
    lines = eval_print(@c, <<'EOF')
#header
static int global = 7;
printf("global: %d", global);
EOF
    assert_equal(1, lines.size)
    assert_equal("global: 7", lines[0])
    global_lineno = `grep -n global c-test/main.c`.split(':').first.to_i
    main_lineno = `grep -n main c-test/main.c`.split(':').first.to_i
    assert(main_lineno > global_lineno)
  end

  # test help command in C
  def test_c09
    lines = eval_print(@c, <<'EOF')
#help
EOF
    cmds = lines.select { |l| /^\#/.match(l) }.map { |l| /^\#([A-Z0-9a-z\-_]+)/.match(l) ? $1 : l }
    %w( arguments class delete dir header help include library list main rm-lib ).each do |cmd|
      assert(cmds.include?(cmd), "expected to find command #{cmd} in output")
    end
  end

  # test list and delete in C
  def test_c10
    lines = eval_print(@c, <<'EOF')
printf("hello");
printf("goodbye");
#list
#delete 001
#list
EOF
    assert_equal(5, lines.size)
    assert_equal("hello", lines[0])
    assert_equal("goodbye", lines[1])
    assert_equal('001> printf("hello");', lines[2])
    assert_equal('002> printf("goodbye");', lines[3])
    assert_equal('001> printf("goodbye");', lines[4])
  end

  # test rm-lib.  If library not there, should be a no-op
  def test_c11
    source = make_file(<<'EOF')
#include "foo.h"
#include <stdio.h>
void say_hello(char *name) {
  printf("Hello, %s\n", name);
}
EOF
    header = make_file(<<'EOF')
void say_hello(char *);
EOF
    lines = eval_print(@c, <<"EOF")
#lib foo #{source.path} #{header.path}
say_hello("Hank");
#delete 002
#rm-lib foo
printf("yes sir");
#rm-lib nada
EOF
    assert_equal(2, lines.size)
    assert_equal("Hello, Hank", lines[0])
    assert_equal("yes sir", lines[1])
    assert(File.exists?('c-test/main.c'))
    assert(!File.exists?('c-test/foo.c'), 'foo.c should have been deleted')
    assert(!File.exists?('c-test/foo.h'), 'foo.h should have been deleted')
    assert(!File.exists?('c-test/foo.o'), 'foo.o should have been deleted')
  end

  def test_c12
    lines = eval_print(@c, <<EOF)
#arg hello
puts(argv[1]);
EOF
    assert_equal(1, lines.size)
    assert_equal("hello", lines[0])
  end

  def test_c13
    lines = eval_print(@c, <<EOF)
#arg hello there
printf("%d", argc);
puts(argv[1]);
puts(argv[2]);
  end
EOF
    assert_equal(3, lines.size)
    ["3", "hello", "there" ].each_with_index do |line, i|
      assert_equal(line, lines[i], "expected line #{i+1} to be #{line}")
    end
  end

  # simple test of C++
  def test_cpp01
    lines = eval_print(@cpp, 'cout << "hello world" << endl;')
    assert_equal(1, lines.size)
    assert_equal('hello world', lines[0])
  end

  # arguments command should set argc and argv
  def test_cpp02
    lines = eval_print(@cpp, <<'EOF')
#arguments one two three
cout << argc << " " << argv[3] << " " << argv[2] << " " << argv[1] << endl;
EOF
    assert_equal(1, lines.size)
    assert_equal("4 three two one", lines[0]);
  end

  # lib command with C++
  def test_cpp03
    header = make_file(<<'EOF')
class Adder {
    public:
    static int add(int first, int second);
};
EOF
    source = make_file(<<'EOF')
#include "Adder.h"
int Adder::add(int first, int second) {
  return first+second;
}
EOF
    lines = eval_print(@cpp, <<"EOF")
#lib Adder #{source.path} #{header.path}
cout << Adder::add(7, 13) << endl;
EOF
    assert_equal(1, lines.size)
    assert_equal("20", lines[0])
  end

  # test delete and list
  def test_cpp04
    lines = eval_print(@cpp, <<'EOF')
cout << "hello" << endl;
cout << "goodbye" << endl;
#delete 001
#list
EOF
    assert_equal(3, lines.size)
    assert_equal("hello", lines[0])
    assert_equal("goodbye", lines[1])
    assert_equal('001> cout << "goodbye" << endl;', lines[2])
  end

  # test help command
  def test_cpp05
    lines = eval_print(@cpp, <<'EOF')
#help
EOF
    cmds = lines.select { |l| /^\#/.match(l) }.map { |l| /^\#([A-Z0-9a-z\-_]+)/.match(l) ? $1 : l }
    %w( arguments class delete dir header help include library list main rm-lib ).each do |cmd|
      assert(cmds.include?(cmd), "expected to find command #{cmd} in output")
    end
  end

  # test dir command
  def test_cpp06
    lines = eval_print(@cpp, <<"EOF")
#dir #{ALTERNATE_DIRECTORY}
printf("does it work");
EOF
    assert_equal(1, lines.size)
    assert_equal("does it work", lines[0])
    assert(File.exists?("#{ALTERNATE_DIRECTORY}/main.cpp"))
  end

  # test #include
  def test_cpp07
    lines = eval_print(@cpp, <<"EOF")
#include <sstream>
stringstream ss("7");
int i;
ss >> i;
cout << i << endl;
EOF
    assert_equal(1, lines.size)
    assert_equal("7", lines[0])
  end
  
  # simple test of objective c
  def test_objc01
    lines = eval_print(@objc, 'printf("hello world\\n");')
    assert_equal(1, lines.size)
    assert_equal('hello world', lines[0])
  end
  
  # arguments command should set argc and argv
  def test_objc02
    lines = eval_print(@objc, <<'EOF')
#arguments one two three
printf("%d %s %s %s", argc, argv[3], argv[2], argv[1]);
EOF
    assert_equal(1, lines.size)
    assert_equal("4 three two one", lines[0])
  end

  # lib command with Objective C
  def test_objc03
    header = make_file(<<'EOF')
#import <Foundation/Foundation.h>
@interface Adder : NSObject {
}
+(int) add: (int)first: (int) second;
@end
EOF
    source = make_file(<<'EOF')
#include "Adder.h"
@implementation Adder
+(int) add: (int) first: (int) second {
  return first+second;
}
@end
EOF
    lines = eval_print(@objc, <<"EOF")
#lib Adder #{source.path} #{header.path}
printf("%d", [Adder add:  7: 13]);
EOF
    assert_equal(1, lines.size)
    assert_equal("20", lines[0])
  end

  # test delete and list
  def test_objc04
    lines = eval_print(@objc, <<'EOF')
printf("hello\n");
printf("goodbye\n");
#delete 001
#list
EOF
    assert_equal(3, lines.size)
    assert_equal("hello", lines[0])
    assert_equal("goodbye", lines[1])
    assert_equal('001> printf("goodbye\\n");', lines[2])
  end

  # test help command
  def test_objc05
    lines = eval_print(@objc, <<'EOF')
#help
EOF
    cmds = lines.select { |l| /^\#/.match(l) }.map { |l| /^\#([A-Z0-9a-z\-_]+)/.match(l) ? $1 : l }
    %w( arguments class delete dir header help include library list main rm-lib ).each do |cmd|
      assert(cmds.include?(cmd), "expected to find command #{cmd} in output")
    end
  end

  # test dir command
  def test_objc06
    lines = eval_print(@objc, <<"EOF")
#dir #{ALTERNATE_DIRECTORY}
printf("does it work");
EOF
    assert_equal(1, lines.size)
    assert_equal("does it work", lines[0])
    assert(File.exists?("#{ALTERNATE_DIRECTORY}/main.m"))
  end

  # test #include and #class in C
  def test_objc07
    lines = eval_print(@objc, <<'EOF')
#include <stdarg.h>
#class
int add(int first, ...) {
  va_list ap;
  va_start(ap, first);
  int second = va_arg(ap, int);
  va_end(ap);
  return first + second;
}
printf("%d\n", add(3,7));
EOF
    assert_equal(1, lines.size);
    assert_equal(10, lines[0].to_i);
  end
  
  # hello world java
  def test_java01
    lines = eval_print(@java, 'System.out.println("hello world");')
    assert_equal(1, lines.size)
    assert_equal('hello world', lines[0])
  end

  # test a java enum, which must be placed outside the Main method
  # but inside the class definition.
  def test_java02
    lines = eval_print(@java, <<EOF)
public enum DayOfWeek { MON, TUE, WED, THU, FRI, SAT, SUN };
printf("Day of Week: %s", DayOfWeek.TUE);
EOF
    assert_equal(1, lines.size)
    assert_equal("Day of Week: TUE", lines[0])
  end

  # test arguments command sets argv array
  def test_java03
    lines = eval_print(@java, <<'EOF')
#arguments real stuff
printf("%s %s", argv[1], argv[0]);
EOF
    assert_equal(1, lines.size)
    assert_equal("stuff real", lines[0])
  end

  # test lib with java
  def test_java04
    source = make_file(<<'EOF')
public class Adder {
  public static int add(int first, int second) {
    return first+second;
  }
}
EOF
    lines = eval_print(@java, <<"EOF")
#lib Adder #{source.path}
printf("%d", Adder.add(7,13));
EOF
    assert_equal(1, lines.size)
    assert_equal("20", lines[0])    
  end

  # test delete and list
  def test_java05
    lines = eval_print(@java, <<'EOF')
printf("hello\n");
printf("goodbye\n");
#delete 001
#list
EOF
    assert_equal(3, lines.size)
    assert_equal("hello", lines[0])
    assert_equal("goodbye", lines[1])
    assert_equal('001> printf("goodbye\\n");', lines[2])
  end

  # test help command
  def test_java06
    lines = eval_print(@java, <<'EOF')
#help
EOF
    cmds = lines.select { |l| /^\#/.match(l) }.map { |l| /^\#([A-Z0-9a-z\-_]+)/.match(l) ? $1 : l }
    %w( arguments class delete dir header help include library list main rm-lib ).each do |cmd|
      assert(cmds.include?(cmd), "expected to find command #{cmd} in output")
    end
  end

  # test dir command
  def test_java07
    lines = eval_print(@java, <<"EOF")
#dir #{ALTERNATE_DIRECTORY}
printf("does it work");
EOF
    assert_equal(1, lines.size)
    assert_equal("does it work", lines[0])
    assert(File.exists?("#{ALTERNATE_DIRECTORY}/Main.java"), "Main.java not found")
  end

  # test package and import
  def test_java08
    source = make_file(<<'EOF')
package path.to;
public class Adder {
  public static int add(int first, int second) {
    return first+second;
  }
}
EOF
    lines = eval_print(@java, <<"EOF")
#lib path.to.Adder #{source.path}
import path.to.*;
printf("%d", Adder.add(7,13));
EOF
    assert_equal(1, lines.size)
    assert_equal("20", lines[0])    
  end

  # test #include causes error
  def test_java09
    lines = eval_print(@java, <<'EOF')
#include <stdarg.h>
EOF
    assert_equal(1, lines.size)
    assert_equal("CREPL: #include not supported for Java", lines[0])
  end
  
  def test_csharp01
    lines = eval_print(@csharp, 'System.Console.WriteLine("hello world");')
    assert_equal(1, lines.size)
    assert_equal('hello world', lines[0])
  end

  # test arguments command sets argv array
  def test_csharp02
    lines = eval_print(@csharp, <<'EOF')
#arguments hello dolly
System.Console.WriteLine("{1} {0}", argv[0], argv[1]);
EOF
    assert_equal(1, lines.size)
    assert_equal("dolly hello", lines[0])
  end

  # test lib with c sharp
  def test_csharp03
    source = make_file(<<'EOF')
public class Adder {
  public static int add(int first, int second) {
    return first+second;
  }
}
EOF
    lines = eval_print(@csharp, <<"EOF")
#lib Adder #{source.path}
printf("{0}", Adder.add(11,17));
EOF
    assert_equal(1, lines.size)
    assert_equal("28", lines[0])    
  end

    # test delete and list
  def test_csharp04
    lines = eval_print(@csharp, <<'EOF')
printf("hello\n");
printf("goodbye\n");
#delete 001
#list
EOF
    assert_equal(3, lines.size)
    assert_equal("hello", lines[0])
    assert_equal("goodbye", lines[1])
    assert_equal('001> printf("goodbye\\n");', lines[2])
  end

    # test help command
  def test_csharp05
    lines = eval_print(@csharp, <<'EOF')
#help
EOF
    cmds = lines.select { |l| /^\#/.match(l) }.map { |l| /^\#([A-Z0-9a-z\-_]+)/.match(l) ? $1 : l }
    %w( arguments class delete dir header help include library list main rm-lib ).each do |cmd|
      assert(cmds.include?(cmd), "expected to find command #{cmd} in output")
    end
  end

    # test dir command
  def test_csharp06
    lines = eval_print(@csharp, <<"EOF")
#dir #{ALTERNATE_DIRECTORY}
printf("does it work");
EOF
    assert_equal(1, lines.size)
    assert_equal("does it work", lines[0])
    assert(File.exists?("#{ALTERNATE_DIRECTORY}/Top.cs"))
  end

  # test namespace and using
  def test_csharp07
    source = make_file(<<'EOF')
namespace path {
  namespace to {
    public class Adder {
      public static int add(int first, int second) {
        return first+second;
      }
    }
  }
}
EOF
    lines = eval_print(@csharp, <<"EOF")
#lib path.to.Adder #{source.path}
using path.to;
printf("{0}", Adder.add(11,17));
EOF
    library_file = File.join(DIRECTORIES[:csharp], 'Adder.cs')
    assert(File.exists?(library_file), "expected file #{library_file} to exist")
    assert_equal(1, lines.size)
    assert_equal("28", lines[0])    
  end

  # test #include causes error
  def test_csharp08
    lines = eval_print(@csharp, <<'EOF')
#include <stdarg.h>
EOF
    assert_equal(1, lines.size)
    assert_equal("CREPL: #include not supported for C#", lines[0])
  end
  
end
