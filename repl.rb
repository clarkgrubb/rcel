#!/usr/bin/env ruby

require 'fileutils'
require 'erb'
require 'readline'
include Readline

C = 'c'
CSHARP = 'c#'
JAVALANG = 'java'
OBJC = 'objective-c'
CPP = 'c++'
LANGUAGES = [ C, CSHARP, JAVALANG, OBJC, CPP ]

def usage
  raise "LANGUAGES: #{LANGUAGES.join(' ')}\nUSAGE: repl.rb LANGUAGE PROJECT_DIR"
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
puts "Working in #{DIRECTORY} using language #{LANGUAGE}"

GCC = `which gcc`.chomp
GPP = `which g++`.chomp
JAVA = `which java`.chomp
JAVAC = `which javac`.chomp
MONO = `which mono`.chomp
MCS = `which mcs`.chomp

COMPILE_EXECUTABLE = {}
COMPILE_EXECUTABLE[C] = '"#{GCC} -o #{executable} #{source}"'
COMPILE_EXECUTABLE[JAVALANG] = '"#{JAVAC} #{File.join(DIRECTORY, SOURCE[JAVALANG])}"'
COMPILE_EXECUTABLE[CSHARP] = '"#{MCS} #{File.join(DIRECTORY, SOURCE[CSHARP])}"'
COMPILE_EXECUTABLE[OBJC] = '"#{GCC} -framework Foundation #{File.join(DIRECTORY, SOURCE[OBJC])} -o #{File.join(DIRECTORY, EXECUTABLE[OBJC])}"'
COMPILE_EXECUTABLE[CPP] = '"#{GPP} -o #{executable} #{source}"'
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
MAIN_TEMPLATE = {}

MAIN_TEMPLATE[C] =<<EOS

#include <stdio.h>

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

  public static void main(String[] args) {
    <% lines.each do |line| %>
    <%= line %>
    <% end %>
  }
}
EOS

MAIN_TEMPLATE[CSHARP] =<<EOS
public class Top {
  public static void Main() {
    <% lines.each do |line| %>
    <%= line %>
    <% end %>
  }
}
EOS

MAIN_TEMPLATE[OBJC] =<<EOS
#import <Foundation/Foundation.h>

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
using namespace std;
int main() {
  <% lines.each do |line| %>
  <%= line %>
  <% end %>
  return 0;
}
EOS

def make_source(lines)
  
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

def compile_source(source)
  executable = File.join(DIRECTORY, EXECUTABLE[LANGUAGE])
  compile_arg = eval(COMPILE_EXECUTABLE[LANGUAGE])
  output = `#{compile_arg}`
  unless $?.success?
    puts "ERROR compiling #{source}"
    puts output
    raise
  end
  executable
end

def run_executable(executable)
  run_arg = eval(RUN_EXECUTABLE[LANGUAGE])
  output = `#{run_arg}`
  unless $?.success?
    puts "ERROR running #{executable}"
    puts output
    raise
  end
  output   
end
  
lines = []
loop do
  line = readline("> ")
  break if line.nil?
  begin
    new_lines = lines.dup
    new_lines << line
    source = make_source(new_lines)
    executable = compile_source(source)
    output = run_executable(executable)
    puts output
    lines = new_lines
  rescue
    puts "ERROR: #{$!.message}"
  end
end
