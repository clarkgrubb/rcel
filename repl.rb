#!/usr/bin/env ruby

require 'fileutils'
require 'erb'
require 'readline'
require File.dirname(__FILE__) + '/clex.rb'
require 'pp'

include Readline

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
  puts "LANGUAGES: #{LANGUAGES.join(' ')}\nUSAGE: repl.rb LANGUAGE PROJECT_DIR"
  exit -1
end
usage unless ARGV.length == 2
if LANGUAGES.include?(ARGV[0].downcase)
  LANGUAGE = ARGV[0].downcase
  DIRECTORY = ARGV[1]
elsif LANGUAGES.include?(ARGV[1].downcase)
  LANGUAGE = ARGV[1].downcase
  DIRECTORY = ARGV[0]
else
  usage
end
FileUtils.mkdir_p DIRECTORY

def help
  case LANGUAGE
  when C
    puts <<EOS
#help: display this menu
#lib <LIBRARY_NAME>: to edit library
#include <HEADER>: to include header
EOS
  when CPP
    puts "implement me"
  when OBJC
    puts "implement me"
  when JAVALANG
    puts "implement me"
  when CSHARP
    puts "implement me"
  end
end

help
puts "Working in #{DIRECTORY} using language #{LANGUAGE}"

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
COMPILE_EXECUTABLE[C] = '"#{GCC} #{GCC_INCLUDE[LANGUAGE]} -o #{executable} #{source} #{all_libraries}"'
COMPILE_EXECUTABLE[JAVALANG] = '"#{JAVAC} -cp #{DIRECTORY} #{File.join(DIRECTORY, SOURCE[JAVALANG])}"'
COMPILE_EXECUTABLE[CSHARP] = '"#{MCS} #{all_libraries.empty? ? \'\': \'-reference:\'}#{all_libraries} #{File.join(DIRECTORY, SOURCE[CSHARP])}"'
COMPILE_EXECUTABLE[OBJC] = '"#{GCC} #{GCC_INCLUDE[LANGUAGE]} -framework Foundation #{File.join(DIRECTORY, SOURCE[OBJC])} -o #{File.join(DIRECTORY, EXECUTABLE[OBJC])} #{all_libraries}"'
COMPILE_EXECUTABLE[CPP] = '"#{GPP} #{GCC_INCLUDE[LANGUAGE]} -o #{executable} #{source} #{all_libraries}"'
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
RUN_EXECUTABLE[JAVALANG] = '"#{JAVA} -cp #{DIRECTORY} #{EXECUTABLE[JAVALANG]}"'
RUN_EXECUTABLE[CSHARP] = '"#{MONO} #{File.join(DIRECTORY, EXECUTABLE[CSHARP])}"'
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
<% headers.each do |header| %>
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

int
main (int argc, char **argv) {
  <% lines.each do |line| %>
  <%= line %>
  <% end %>
  return 0;
}
EOS

MAIN_TEMPLATE[JAVALANG] =<<EOS

public class Main {

  public static void p(String msg) {
    System.out.println(msg);
  }

  public static void main(String[] args) {
    <% lines.each do |line| %>
    <%= line %>
    <% end %>
  }
}
EOS

MAIN_TEMPLATE[CSHARP] =<<EOS
public class Top {
  public static void p(System.String msg) {
    System.Console.WriteLine(msg);
  }

  public static void Main() {
    <% lines.each do |line| %>
    <%= line %>
    <% end %>
  }
}
EOS

MAIN_TEMPLATE[OBJC] =<<EOS
#import <Foundation/Foundation.h>
<% headers.each do |header| %>
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

int main (int argc, const char * argv[]) {
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  <% lines.each do |line| %>
  <%= line %>
  <% end %>
  [pool drain];
  return 0;
}
EOS

MAIN_TEMPLATE[CPP] = <<EOS
#include <iostream>
<% headers.each do |header| %>
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

int main() {
  <% lines.each do |line| %>
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

def make_source(lines, headers)  
  stdout = $stdout
  source = File.join(DIRECTORY,SOURCE[LANGUAGE])
  begin
    $stdout = File.open(source,'w')
    ERB.new(MAIN_TEMPLATE[LANGUAGE]).run(binding)
    $stdout.flush
  ensure
    $stdout = stdout
  end
  source
end

def compile_executable(source, libraries)
  all_libraries = source_to_object(libraries).map { |lib| File.join(DIRECTORY, lib) }.join(LIBRARY_CONNECTOR[LANGUAGE])
  executable = File.join(DIRECTORY, EXECUTABLE[LANGUAGE])
  compile_arg = eval(COMPILE_EXECUTABLE[LANGUAGE], binding)
  puts "DEBUG compile_executable: #{compile_arg}"
  output = `#{compile_arg}`
  unless $?.success?
    puts "ERROR compiling #{source}"
    puts output
    raise CompilationError
  end
  executable
end

def source_to_object(arg)
  if arg.respond_to?(:map)
    arg.map { |o| source_to_object(o) }
  else
    arg.sub(/#{SOURCE_SUFFIX[LANGUAGE]}$/,  OBJECT_SUFFIX[LANGUAGE])
  end
end

def compile_library(library_basename)
  compiled_library_basename = source_to_object(library_basename)
  compiled_library = File.join(DIRECTORY, compiled_library_basename)
  library = File.join(DIRECTORY, library_basename)
  compile_arg = eval(COMPILE_LIBRARY[LANGUAGE])
  puts "DEBUG compile_library: #{compile_arg}"
  output = `#{compile_arg}`
  unless $?.success?
    puts "ERROR compiling #{library}"
    puts output
    raise CompilationError
  end
  compiled_library_basename
end

def run_executable(executable)
  run_arg = eval(RUN_EXECUTABLE[LANGUAGE])
  output = `#{run_arg}`
  unless $?.success?
    puts "ERROR running #{executable}"
    puts output
    raise ExecutionError
  end
  output   
end

def get_base_name(name)
  suffix = HEADER_SUFFIX[LANGUAGE] ? "(#{HEADER_SUFFIX[LANGUAGE]}|#{SOURCE_SUFFIX[LANGUAGE]})" : "(#{SOURCE_SUFFIX[LANGUAGE]})"
  /^(.+)(\.#{suffix})?$/.match(name) ? $1: nil
end

def edit_library(name, opts)
  libraries = opts[:libraries]
  headers = opts[:headers]
  base_name = get_base_name(name)
  if base_name
    files = []
    source = "#{base_name}.#{SOURCE_SUFFIX[LANGUAGE]}"
    files << source
    header = HEADER_SUFFIX[LANGUAGE] ? "#{base_name}.#{HEADER_SUFFIX[LANGUAGE]}" : nil
    files << header if header
    files.map! { |f| File.join(DIRECTORY,f) }
    system("#{EDITOR} #{files.join(' ')}")
    object = compile_library(source)
    if files.inject {|m,f| m and File.exists?(f) }
      libraries << source
      libraries.uniq!
      headers << header if header
      headers.uniq!
    else
      puts "no library created"
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
  tokens = $clex.stream(line)
  if tokens.size > 1 and braces_balanced?(tokens)
    ult = tokens.pop
    penult = tokens.pop
    return true if :end == ult.first and :punctuator == penult.first and [';','}'].include?(penult.last)
  end
  get_command(line)
end

def puts_output(output, last_output)
  if output.length >= last_output.length and last_output == output[0,last_output.length]
    puts output[last_output.length,output.length]
  else
    puts output
  end
end

$clex = Clex.new(CLEX_LANGUAGE[LANGUAGE])
lines = []
last_output = ''
libraries = []
Dir.new(DIRECTORY).each { |f| libraries << f if f.match(/#{OBJECT_SUFFIX[LANGUAGE]}$/) }
puts "Using libraries: #{libraries.join(' ')}" unless libraries.empty?
headers = []
Dir.new(DIRECTORY).each { |f| headers << f if f.match(/#{HEADER_SUFFIX[LANGUAGE]}$/) } if HEADER_SUFFIX[LANGUAGE]
puts "Using headers: #{headers.join(' ')}" unless headers.empty?
loop do
  line = ''
  continued_line = false
  loop do
    part = readline("#{continued_line ? '...' : ("%03d" % (lines.size + 1))}> ", true)
    if part.nil?
      puts
      exit
    end
    line << part
    break if line_complete?(line)
    continued_line = true
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
        puts "DEBUG line #{line}"
        puts "DEBUG cmd_arg #{cmd_arg}"
        new_headers = headers.dup
        new_headers << cmd_arg unless headers.include?(cmd_arg)
        source = make_source(lines, new_headers)
        executable = compile_executable(source, libraries)
        headers = new_headers
      rescue CompilationError
        puts "failed to include #{cmd_arg}"
      end
    else
      puts "Unrecognized command: #{lib}"
    end
  else
    begin
      new_lines = lines.dup
      new_lines << line
      source = make_source(new_lines, headers)
      executable = compile_executable(source, libraries)
      output = run_executable(executable)
      puts_output(output, last_output)
      last_output = output
      lines = new_lines
    rescue CompilationError, ExecutionError
    end
  end
end
