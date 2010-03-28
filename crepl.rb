#!/usr/bin/env ruby

require 'fileutils'
require 'erb'
require 'readline'
require File.dirname(__FILE__) + '/clex.rb'
require 'pp'

class Crepl
  
  include Readline

  attr_accessor :language, :directory
  
  class ParseError < StandardError; end
  class CompilationError < StandardError; end
  class ExecutionError < StandardError; end
  class LibraryEditError < StandardError; end
  
  C = 'c'
  CSHARP = 'c#'
  JAVALANG = 'java'
  OBJC = 'objective-c'
  CPP = 'c++'
  LANGUAGES = [ C, CSHARP, JAVALANG, OBJC, CPP ]
  
  def usage
    puts "LANGUAGES: #{LANGUAGES.join(' ')}\nUSAGE: crepl.rb LANGUAGE PROJECT_DIR"
    exit -1
  end

  def help
    case @language
    when C
      @out.puts <<EOS
#help: display this menu
#lib <LIBRARY_NAME>: to edit library
#include <HEADER>: to include header
EOS
    when CPP
      @out.puts "implement me"
    when OBJC
      @out.puts "implement me"
    when JAVALANG
      @out.puts "implement me"
    when CSHARP
      @out.puts "implement me"
    end
  end

  GCC = `which gcc`.chomp
  GPP = `which g++`.chomp
  JAVA = `which java`.chomp
  JAVAC = `which javac`.chomp
  MONO = `which mono`.chomp
  MCS = `which gmcs`.chomp

  EDITOR = ENV['EDITOR'] || 'emacs'
  GCC_INCLUDE = {}
  GCC_INCLUDE[C] = ''
  GCC_INCLUDE[CPP] = ''
  GCC_INCLUDE[OBJC] = ''
  COMPILE_EXECUTABLE = {}
  COMPILE_EXECUTABLE[C] = '"#{GCC} #{GCC_INCLUDE[@language]} -o #{executable} #{source} #{all_libraries}"'
  COMPILE_EXECUTABLE[JAVALANG] = '"#{JAVAC} -cp #{@directory} #{File.join(@directory, SOURCE[JAVALANG])}"'
  COMPILE_EXECUTABLE[CSHARP] = '"#{MCS} #{all_libraries.empty? ? \'\': \'-reference:\'}#{all_libraries} #{File.join(@directory, SOURCE[CSHARP])}"'
  COMPILE_EXECUTABLE[OBJC] = '"#{GCC} #{GCC_INCLUDE[@language]} -framework Foundation #{File.join(@directory, SOURCE[OBJC])} -o #{File.join(@directory, EXECUTABLE[OBJC])} #{all_libraries}"'
  COMPILE_EXECUTABLE[CPP] = '"#{GPP} #{GCC_INCLUDE[@language]} -o #{executable} #{source} #{all_libraries}"'
  COMPILE_LIBRARY = {}
  COMPILE_LIBRARY[C] = '"#{GCC} -c #{library} -o #{compiled_library}"'
  COMPILE_LIBRARY[JAVALANG] = '"#{JAVAC} #{library}"'
  COMPILE_LIBRARY[CSHARP] = '"#{MCS} -target:library #{library}"'
  COMPILE_LIBRARY[OBJC] = '"#{GCC} -c #{library} -o #{compiled_library}"'
  COMPILE_LIBRARY[CPP] = '"#{GPP} -c #{library} -o #{compiled_library}"'
  # TODO other languages
  EXECUTABLE = {}
  EXECUTABLE[C] = 'main'
  EXECUTABLE[JAVALANG] = 'Main'
  EXECUTABLE[CSHARP] = 'Top.exe'
  EXECUTABLE[OBJC] = 'main'
  EXECUTABLE[CPP] = 'main'
  SOURCE = {}
  SOURCE[C] = 'main.c'
  SOURCE[JAVALANG] = 'Main.java'
  SOURCE[CSHARP] = 'Top.cs'
  SOURCE[OBJC] = 'main.m'
  SOURCE[CPP] = 'main.cpp'
  RUN_EXECUTABLE = {}
  RUN_EXECUTABLE[C] = '"#{executable}"'
  RUN_EXECUTABLE[JAVALANG] = '"#{JAVA} -cp #{@directory} #{EXECUTABLE[JAVALANG]}"'
  RUN_EXECUTABLE[CSHARP] = '"#{MONO} #{File.join(@directory, EXECUTABLE[CSHARP])}"'
  RUN_EXECUTABLE[OBJC] = '"#{executable}"'
  RUN_EXECUTABLE[CPP] = '"#{executable}"'
  SOURCE_SUFFIX = { C => 'c', JAVALANG => 'java', CSHARP => 'cs', OBJC => 'm', CPP => 'cpp' }
  HEADER_SUFFIX = { C => 'h', JAVALANG => nil, CSHARP => nil, OBJC => 'h', CPP => 'h' }
  OBJECT_SUFFIX = { C => 'o', JAVALANG => 'class', CSHARP => 'dll', OBJC => 'o', CPP => 'o' }
  LIBRARY_CONNECTOR = { C => ' ', JAVALANG => ' ', CSHARP => ',', OBJC => ' ', CPP => ' ' }
  CLEX_LANGUAGE = { C => :c, JAVALANG => :java, CSHARP => :csharp, OBJC => :objective_c, CPP => :cpp }

  MAIN_TEMPLATE = {}

  MAIN_TEMPLATE[C] =<<EOS

#include <stdio.h>
#include <stdarg.h>
<% header_lines.each do |header| %>
<%= '#include ' + quote_header(header) %>
<% end %>

void
p(char *msg) {
  puts(msg);
}

void
pf(char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  vprintf(fmt, ap);
}

<% class_lines.each do |line| %>
<%= line %>
<% end %>

int
main (int argc, char **argv) {
  <% main_lines.each do |line| %>
  <%= line %>
  <% end %>
  return 0;
}
EOS

  MAIN_TEMPLATE[JAVALANG] =<<EOS

import static java.lang.System.out;

<% header_lines.each do |line| %>
<%= line %>
<% end %>

public class Main {

  public static void p(String msg) {
    System.out.println(msg);
  }

  public static void pf(String fmt) {
    System.out.printf(fmt);
  }
  <% (1..5).each do |args| %>
  public static void pf(String fmt, <%= (1..args).map { |i| 'Object o' + i.to_s }.join(', ') %>) {
    System.out.printf(fmt, <%= (1..args).map { |i| 'o' + i.to_s }.join(', ') %>);
  }
  <% end %>

  <% class_lines.each do |line| %>
  <%= line %>
  <% end %>

  public static void main(String[] args) {
    <% main_lines.each do |line| %>
    <%= line %>
    <% end %>
  }
}
EOS

  MAIN_TEMPLATE[CSHARP] =<<EOS

<% header_lines.each do |line| %>
<%= line %>
<% end %>

public class Top {
  public static void p(System.String msg) {
    System.Console.WriteLine(msg);
  }

  public static void pf(System.String fmt, params object[] list) {
    System.Console.WriteLine(string.Format(fmt, list));
  }

  <% class_lines.each do |line| %>
  <%= line %>
  <% end %>

  public static void Main() {
    <% main_lines.each do |line| %>
    <%= line %>
    <% end %>
  }
}
EOS

  MAIN_TEMPLATE[OBJC] =<<EOS
#import <Foundation/Foundation.h>
<% header_lines.each do |header| %>
<%= '#include ' + quote_header(header) %>
<% end %>

void
p(char *msg) {
  puts(msg);
}

void
pf(char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  vprintf(fmt, ap);
}

<% class_lines.each do |line| %>
<%= line %>
<% end %>

int main (int argc, const char * argv[]) {
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  <% main_lines.each do |line| %>
  <%= line %>
  <% end %>
  [pool drain];
  return 0;
}
EOS

  MAIN_TEMPLATE[CPP] = <<EOS
#include <iostream>
<% header_lines.each do |header| %>
<%= '#include ' + quote_header(header) %>
<% end %>
using namespace std;

void
p(const char *msg) {
  puts(msg);
}

void
pf(const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  vprintf(fmt, ap);
}

<% class_lines.each do |line| %>
<%= line %>
<% end %>

int main() {
  <% main_lines.each do |line| %>
  <%= line %>
  <% end %>
  return 0;
}
EOS

  def quote_header(header)
    if /^\".+\"$/.match(header) or /^\<.+\>$/.match(header)
      header
    else
      '"' + header + '"'
    end
  end

  def make_source(lines)  
    stdout = $stdout
    source = File.join(@directory,SOURCE[@language])
    header_lines = lines.header_lines
    class_lines = lines.class_lines
    main_lines = lines.main_lines
    begin
      $stdout = File.open(source,'w')
      ERB.new(MAIN_TEMPLATE[@language]).run(binding)
      $stdout.flush
    ensure
      $stdout = stdout
    end
    source
  end

  def compile_executable(source, libraries)
    all_libraries = source_to_object(libraries).map { |lib| File.join(@directory, lib) }.join(LIBRARY_CONNECTOR[@language])
    executable = File.join(@directory, EXECUTABLE[@language])
    compile_arg = eval(COMPILE_EXECUTABLE[@language], binding)
    @out.puts "DEBUG compile_executable: #{compile_arg}" if @debug
    output = `#{compile_arg}`
    unless $?.success?
      @out.puts "ERROR compiling #{source}"
      @out.puts output
      raise CompilationError
    end
    executable
  end

  def source_to_object(arg)
    if arg.respond_to?(:map)
      arg.map { |o| source_to_object(o) }
    else
      arg.sub(/#{SOURCE_SUFFIX[@language]}$/,  OBJECT_SUFFIX[@language])
    end
  end

  def compile_library(library_basename)
    compiled_library_basename = source_to_object(library_basename)
    compiled_library = File.join(@directory, compiled_library_basename)
    library = File.join(@directory, library_basename)
    compile_arg = eval(COMPILE_LIBRARY[@language])
    @out.puts "DEBUG compile_library: #{compile_arg}" if @debug
    output = `#{compile_arg}`
    unless $?.success?
      @out.puts "ERROR compiling #{library}"
      @out.puts output
      raise CompilationError
    end
    compiled_library_basename
  end

  def run_executable(executable)
    run_arg = eval(RUN_EXECUTABLE[@language])
    output = `#{run_arg}`
    unless $?.success?
      @out.puts "ERROR running #{executable}"
      @out.puts output
      raise ExecutionError
    end
    output   
  end

  def get_base_name(name)
    suffix = HEADER_SUFFIX[@language] ? "(#{HEADER_SUFFIX[@language]}|#{SOURCE_SUFFIX[@language]})" : "(#{SOURCE_SUFFIX[@language]})"
    /^(.+)(\.#{suffix})?$/.match(name) ? $1: nil
  end

  def edit_library(name, opts)
    libraries = opts[:libraries]
    headers = opts[:headers]
    base_name = get_base_name(name)
    if base_name
      files = []
      source = "#{base_name}.#{SOURCE_SUFFIX[@language]}"
      files << source
      header = HEADER_SUFFIX[@language] ? "#{base_name}.#{HEADER_SUFFIX[@language]}" : nil
      files << header if header
      files.map! { |f| File.join(@directory,f) }
      system("#{EDITOR} #{files.join(' ')}")
      object = compile_library(source)
      if files.inject {|m,f| m and File.exists?(f) }
        libraries << source
        libraries.uniq!
        headers << header if header
        headers.uniq!
      else
        @out.puts "no library created"
      end
    else
      raise LibraryEditError.new("bad name: #{name}")
    end  
  end

  def get_command(line)
    if /^\#(help)/.match(line)
      return [$1,nil]
    elsif /^\#(lib)\s+([a-zA-Z0-9.]+)\s*/.match(line)
      [$1,$2]
    elsif /^\#(include)\s+(["<].+[">])\s*/.match(line)
      [$1,$2]
    elsif /^\#(list)/.match(line)
      [$1,nil]
    elsif /^\#(delete)\s+(\d+)/.match(line)
      [$1,$2.to_i]
    else
      nil
    end
  end

  def braces_balanced?(tokens)
    cnt = 0;
    tokens.each do |token, value|
      if :punctuator == token
        case value
        when '{'
          cnt += 1
        when '}'
          cnt -= 1
        else
        end
      end
      raise ParseError.new("close brace without a preceding open brace") if cnt < 0
    end
    0 == cnt
  end

  def line_complete?(line)
    tokens = @clex.stream(line)
    if tokens.size > 1 and braces_balanced?(tokens)
      ult = tokens.pop
      penult = tokens.pop
      return true if :end == ult.first and :punctuator == penult.first and [';','}'].include?(penult.last)
    end
    get_command(line)
  end

  def puts_output(output, last_output)
    if output.length >= last_output.length and last_output == output[0,last_output.length]
      @out.puts output[last_output.length,output.length]
    else
      @out.puts output
    end
  end

  def prompt_for_language
    print "choose a language (#{LANGUAGES.join(' ')}): "
    language = gets.strip.downcase
    unless LANGUAGES.include?(language)
      raise "not an option: #{llanguage}"
    end
    language
  end

  def initialize(args, opts={})
    @debug = opts[:debug]
    case args.length
    when 2
      if LANGUAGES.include?(args[0].downcase)
        @language = args[0].downcase
        @directory = args[1]
      elsif LANGUAGES.include?(args[1].downcase)
        @language = args[1].downcase
        @directory = args[0]
      else
        raise "neither argument is a supported language"
      end
    when 1
      if LANGUAGES.include?(args[0].downcase)
        @language = args[0].downcase
      else
        @directory = args[0]
      end
    when 0
      # noop
    else
      raise "too many args"
    end
  end

  def repl(opts = {})
    raise "no language" unless @language
    raise "no directory" unless @directory
    FileUtils.mkdir_p @directory
    @out = opts[:output] || $stdout
    @in = opts[:input] || $stdin
    @clex = Clex.new(CLEX_LANGUAGE[@language])
    lines = Lines.new(@language)
    last_output = ''
    libraries = []
    Dir.new(@directory).each { |f| libraries << f if f.match(/#{OBJECT_SUFFIX[@language]}$/) }
    @out.puts "Using libraries: #{libraries.join(' ')}" unless libraries.empty?
    Dir.new(@directory).each { |f| lines.header_lines << f if f.match(/#{HEADER_SUFFIX[@language]}$/) } if HEADER_SUFFIX[@language]
    @out.puts "Using headers: #{lines.header_lines.join(' ')}" unless lines.header_lines.empty?
    loop do
      line = ''
      begin
        continued_line = false
        loop do
          if @in == $stdin
            part = readline("#{continued_line ? '...' : ("%03d" % (lines.size + 1))}> ", true)
          else
            part = @in.gets
          end
          if part.nil?
            @out.puts
            return
          end
          line << part
          break if line_complete?(line)
          continued_line = true
        end
      rescue ParseError
        @out.puts "clex reports that input doesn't lex: #{$!.message}"
        next
      end
      break if line.nil?
      cmd,cmd_arg = get_command(line)
      if cmd
        case cmd
        when 'lib'
          begin
            edit_library(cmd_arg, :libraries => libraries, :headers => headers)
          rescue CompilationError
          end
        when 'help'
          help
        when 'include'
          begin
            @out.puts "DEBUG line #{line}" if @debug
            @out.puts "DEBUG cmd_arg #{cmd_arg}" if @debug
            new_lines = lines.dup
            new_lines.header_lines << cmd_arg unless headers.include?(cmd_arg)
            source = make_source(new_lines)
            executable = compile_executable(source, libraries)
            lines = new_lines
          rescue CompilationError
            @out.puts "failed to include #{cmd_arg}"
          end
        when 'list'
          lines.list
        when 'delete'
          begin
            lines.delete(cmd_arg)
            last_output = '' if 0 == lines.size
          rescue
            @out.puts "couldn't delete line #{cmd_arg}: #{$!.message}"
          end
        else
          @out.puts "Unrecognized command: #{lib}"
        end
      else
        begin
          new_lines = lines.dup
          new_lines.add(line)
          source = make_source(new_lines)
          executable = compile_executable(source, libraries)
          output = run_executable(executable)
          puts_output(output, last_output)
          last_output = output
          lines = new_lines
        rescue CompilationError, ExecutionError
        end
      end
    end
  end
end

class Crepl
  class Lines

    attr_accessor :header_lines, :class_lines, :main_lines

    CLASS_TESTS_JAVA =
      [ lambda {|l| /\A\s*(public|protected|private)\s+enum\b/.match(l) },
      ]
    CLASS_TESTS_CSHARP =
      [ lambda {|l| /\A\s*(public\s+)?enum\b/.match(l) },
      ]
    
    def initialize(language)
      @language = language
      raise "unrecognized language #{@language}" unless LANGUAGES.include?(@language)
      @header_lines = []
      @class_lines = []
      @main_lines = []
      @header_tests = []
      @class_tests = []
      case @language
      when JAVALANG
        @class_tests = CLASS_TESTS_JAVA
      when CSHARP
        @class_tests = CLASS_TESTS_CSHARP
      end
    end

    def dup
      retval = Lines.new(@language)
      retval.header_lines = @header_lines.dup
      retval.class_lines = @class_lines.dup
      retval.main_lines = @main_lines.dup
      retval
    end

    def size
      [@header_lines,@class_lines,@main_lines].inject(0) {|m,o| m+o.size }
    end
    
    def add(line)
      if @header_tests.inject(false) { |m,o| m or o.call(line) }
        @header_lines << line
      elsif @class_tests.inject(false) { |m,o| m or o.call(line) }
        @class_lines << line
      else
        @main_lines << line
      end
    end

    def list
      lineno = 1
      [@header_lines, @class_lines, @main_lines].each do |a|
        a.each do |ll|
          ll.split("\n").each_with_index do |l,i|
            if 0 == i
              puts "%03d> %s" % [ lineno, l]
            else
              puts "...> %s" % l
            end
            lineno += 1
          end
        end
      end
    end

    def delete(lineno)
      raise "line number must be positive" if lineno <= 0
      [@header_lines, @class_lines, @main_lines].each do |a|
        if lineno <= a.size
          a.delete_at(lineno-1)
          return
        end
        lineno -= a.size
      end
    end
  end
end  


if $0 == __FILE__
  crepl = Crepl.new(ARGV)
  crepl.language = crepl.prompt_for_language unless crepl.language
  crepl.directory = "#{crepl.language}-project" unless crepl.directory
  puts "Working in #{crepl.directory} using language #{crepl.language}"
  crepl.repl
end
