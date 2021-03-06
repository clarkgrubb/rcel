#!/usr/bin/env ruby

require 'fileutils'
require 'erb'
require 'readline'
require File.dirname(__FILE__) + '/clex.rb'
require File.dirname(__FILE__) + '/fortran_lex.rb'
require File.dirname(__FILE__) + '/pascal_lex.rb'
require 'pp'

class Rcel

  include Readline

  attr_accessor :language, :directory

  class CompilationError < StandardError; end
  class ExecutionError < StandardError; end
  class LibraryEditError < StandardError; end

  C = 'c'
  CSHARP = 'c#'
  JAVALANG = 'java'
  OBJC = 'objective-c'
  CPP = 'c++'
  FORTRAN95 = 'fortran95'
  PASCAL = 'pascal'
  LANGUAGES = [ C, CSHARP, JAVALANG, OBJC, CPP, FORTRAN95, PASCAL ]

  def usage
    puts "LANGUAGES: #{LANGUAGES.join(' ')}\nUSAGE: rcel.rb LANGUAGE PROJECT_DIR"
    exit -1
  end

  def help
    @out.puts File.read(File.join(TEMPLATE_DIR,'help.txt'))
  end

  OS_TYPE = `uname -s`.chomp
  OS_TYPE_LINUX = 'Linux'
  OS_TYPE_DARWIN = 'Darwin'

  CLANG = `which clang`.chomp
  CLANGPP = `which clang++`.chomp
  CLANGPP11 = "#{CLANGPP} -std=c++11 -stdlib=libc++"
  GCC = `which gcc`.chomp
  GPP = `which g++`.chomp
  GPP11 = "#{GPP} -std=c++0x"
  JAVA = `which java`.chomp
  JAVAC = `which javac`.chomp
  MONO = `which mono`.chomp
  MCS = `which gmcs`.chomp
  GFORTRAN = `which gfortran`.chomp
  FPC = `which fpc`.chomp

  GCC_INCLUDE = {C=>'',CPP=>'',OBJC=>''}
  COMPILE_EXECUTABLE = {}
  COMPILE_EXECUTABLE[C] = '"#{GCC} #{GCC_INCLUDE[@language]} -o #{executable} #{source} #{all_libraries}"'
  COMPILE_EXECUTABLE[JAVALANG] = '"#{JAVAC} -cp #{@directory} #{File.join(@directory, SOURCE[JAVALANG])}"'
  COMPILE_EXECUTABLE[CSHARP] = '"#{MCS} #{all_libraries.empty? ? \'\': \'-reference:\'}#{all_libraries} #{File.join(@directory, SOURCE[CSHARP])}"'
  COMPILE_EXECUTABLE[OBJC] = '"#{GCC} #{GCC_INCLUDE[@language]} -framework Foundation #{File.join(@directory, SOURCE[OBJC])} -o #{File.join(@directory, EXECUTABLE[OBJC])} #{all_libraries}"'
  if OS_TYPE == OS_TYPE_DARWIN
    COMPILE_EXECUTABLE[CPP] = '"#{CLANGPP11} #{GCC_INCLUDE[@language]} -o #{executable} #{source} #{all_libraries}"'    
  else
    COMPILE_EXECUTABLE[CPP] = '"#{GPP11} #{GCC_INCLUDE[@language]} -o #{executable} #{source} #{all_libraries}"'
  end
  COMPILE_EXECUTABLE[FORTRAN95] = '"#{GFORTRAN} -o #{executable} #{source}"'
  COMPILE_EXECUTABLE[PASCAL] = '"#{FPC} #{source}"'
  COMPILE_LIBRARY = {}
  COMPILE_LIBRARY[C] = '"#{GCC} -c #{library} -o #{compiled_library}"'
  COMPILE_LIBRARY[JAVALANG] = '"#{JAVAC} -cp #{@directory} #{library}"'
  COMPILE_LIBRARY[CSHARP] = '"#{MCS} -target:library #{library}"'
  COMPILE_LIBRARY[OBJC] = '"#{GCC} -c #{library} -o #{compiled_library}"'
  if OS_TYPE == OS_TYPE_DARWIN
    COMPILE_LIBRARY[CPP] = '"#{CLANGPP11} -c #{library} -o #{compiled_library}"'
  else
    COMPILE_LIBRARY[CPP] = '"#{GPP11} -c #{library} -o #{compiled_library}"'
  end
  EXECUTABLE = {C=>'main',
    JAVALANG=>'Main',
    CSHARP=>'Top.exe',
    OBJC=>'main',
    CPP=>'main',
    FORTRAN95=>'main',
    PASCAL=>'main'}
  SOURCE = {C=>'main.c',
    JAVALANG=>'Main.java',
    CSHARP=>'Top.cs',
    OBJC=>'main.m',
    CPP=>'main.cpp',
    FORTRAN95=>'main.f95',
    PASCAL=>'main.pas'}
  RUN_EXECUTABLE = {}
  RUN_EXECUTABLE[C] = '"#{executable}"'
  RUN_EXECUTABLE[JAVALANG] = '"#{JAVA} -cp #{@directory} #{EXECUTABLE[JAVALANG]}"'
  RUN_EXECUTABLE[CSHARP] = '"#{MONO} #{File.join(@directory, EXECUTABLE[CSHARP])}"'
  RUN_EXECUTABLE[OBJC] = '"#{executable}"'
  RUN_EXECUTABLE[CPP] = '"#{executable}"'
  RUN_EXECUTABLE[FORTRAN95] = '"#{executable}"'
  RUN_EXECUTABLE[PASCAL] = '"#{executable}"'
  SOURCE_SUFFIX = { C => 'c', JAVALANG => 'java', CSHARP => 'cs', OBJC => 'm', CPP => 'cpp', FORTRAN95 => 'f95', PASCAL => 'pas' }
  HEADER_SUFFIX = { C => 'h', JAVALANG => nil, CSHARP => nil, OBJC => 'h', CPP => 'h' }
  OBJECT_SUFFIX = { C => 'o', JAVALANG => 'class', CSHARP => 'dll', OBJC => 'o', CPP => 'o', FORTRAN95 => 'o', PASCAL => 'o' }
  LIBRARY_CONNECTOR = { C => ' ', JAVALANG => ' ', CSHARP => ',', OBJC => ' ', CPP => ' ' }
  LEX_LANGUAGE = { C => :c,
    JAVALANG => :java,
    CSHARP => :csharp,
    OBJC => :objective_c,
    CPP => :cpp,
    FORTRAN95 => :fortran95,
    PASCAL => :pascal}
  MAIN_TEMPLATE = {}
  TEMPLATE_DIR = File.join(File.dirname(__FILE__), 'templates')
  MAIN_TEMPLATE[C] = File.read(File.join(TEMPLATE_DIR, 'c-main.erb'))
  MAIN_TEMPLATE[JAVALANG] = File.read(File.join(TEMPLATE_DIR, 'java-main.erb'))
  MAIN_TEMPLATE[CSHARP] = File.read(File.join(TEMPLATE_DIR, 'csharp-main.erb'))
  MAIN_TEMPLATE[OBJC] = File.read(File.join(TEMPLATE_DIR, 'objc-main.erb'))
  MAIN_TEMPLATE[CPP] = File.read(File.join(TEMPLATE_DIR, 'cpp-main.erb'))
  MAIN_TEMPLATE[FORTRAN95] = File.read(File.join(TEMPLATE_DIR, 'fortran95-main.erb'))
  MAIN_TEMPLATE[PASCAL] = File.read(File.join(TEMPLATE_DIR, 'pascal-main.erb'))
  LIBRARY_SOURCE_TEMPLATE = {}
  LIBRARY_HEADER_TEMPLATE = {}
  LIBRARY_SOURCE_TEMPLATE[C] = File.read(File.join(TEMPLATE_DIR, 'c-library-source.erb'))
  LIBRARY_HEADER_TEMPLATE[C] = File.read(File.join(TEMPLATE_DIR, 'c-library-header.erb'))
  LIBRARY_SOURCE_TEMPLATE[CPP] = File.read(File.join(TEMPLATE_DIR, 'cpp-library-source.erb'))
  LIBRARY_HEADER_TEMPLATE[CPP] = File.read(File.join(TEMPLATE_DIR, 'cpp-library-header.erb'))
  LIBRARY_SOURCE_TEMPLATE[OBJC] = File.read(File.join(TEMPLATE_DIR, 'objc-library-source.erb'))
  LIBRARY_HEADER_TEMPLATE[OBJC] = File.read(File.join(TEMPLATE_DIR, 'objc-library-header.erb'))
  LIBRARY_SOURCE_TEMPLATE[JAVALANG] = File.read(File.join(TEMPLATE_DIR, 'java-library-source.erb'))
  LIBRARY_SOURCE_TEMPLATE[CSHARP] = File.read(File.join(TEMPLATE_DIR, 'csharp-library-source.erb'))
  HEADER_KEYWORDS = { C => [],
    CPP => [],
    OBJC => [],
    JAVALANG => %w( import ),
    CSHARP => %w( using ),
    FORTRAN95 => [],
    PASCAL => []}
  NAMESPACE_SEPARATOR = { C => nil, OBJC => nil, CPP => '::', JAVALANG => '.', CSHARP => '.' }

  def lexer(lang)
    if :fortran95 == lang
      FortranLex.new(lang)
    elsif :pascal == lang
      PascalLex.new(lang)
    else
      Clex.new(lang)
    end
  end

  def quote_header(header)
    if /^\".+\"$/.match(header) or /^\<.+\>$/.match(header)
      header
    else
      '"' + header + '"'
    end
  end

  def set_editor(choice=nil)
    unless choice
      @out.print("RCEL: choose an editor [vi]: ")
      choice = @in.gets.strip
    end
    ENV['EDITOR'] = /\S/.match(choice) ? choice : 'vi'
  end

  def get_editor
    set_editor unless ENV['EDITOR']
    ENV['EDITOR']
  end

  def make_source(session)
    stdout = $stdout
    source = File.join(@directory,SOURCE[@language])
    header_lines = session.header_lines
    class_lines = session.class_lines
    main_lines = session.main_lines
    begin
      $stdout = File.open(source,'w')
      ERB.new(MAIN_TEMPLATE[@language]).run(binding)
      $stdout.flush
    ensure
      $stdout = stdout
    end
    source
  end

  def make_library_file(session, template, file, name_array)
    namespace_array = name_array.dup
    library = namespace_array.pop
    return if File.exists?(file)
    stdout = $stdout
    begin
      $stdout = File.open(file, 'w')
      ERB.new(template).run(binding)
      $stdout.flush
    ensure
      $stdout = stdout
    end
  end

  def compile_executable(source, libraries)
    all_libraries = source_to_object(libraries).join(LIBRARY_CONNECTOR[@language])
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
    if arg.kind_of?(Array)
      arg.map { |o| source_to_object(o) }
    else
      arg.sub(/#{SOURCE_SUFFIX[@language]}$/,  OBJECT_SUFFIX[@language])
    end
  end

  def compile_library(library)
    compiled_library = source_to_object(library)
    compile_arg = eval(COMPILE_LIBRARY[@language])
    @out.puts "DEBUG compile_library: #{compile_arg}" if @debug
    output = `#{compile_arg}`
    unless $?.success?
      @out.puts "ERROR compiling #{library}"
      @out.puts output
      raise CompilationError
    end
    compiled_library
  end

  def run_executable(executable, arguments)
    run_arg = eval(RUN_EXECUTABLE[@language])
    output = `#{run_arg} #{arguments}`
    unless $?.success?
      @out.puts "ERROR running #{executable}"
      @out.puts output
      raise ExecutionError
    end
    output
  end

  def get_name_array(name)
    suffix = HEADER_SUFFIX[@language] ? "(#{HEADER_SUFFIX[@language]}|#{SOURCE_SUFFIX[@language]})" : "(#{SOURCE_SUFFIX[@language]})"
    fully_qualified_name = name[/^(.+)(\.#{suffix})?$/, 1]
    raise LibraryEditError.new("bad name: #{name}") unless fully_qualified_name
    NAMESPACE_SEPARATOR[@language] ? fully_qualified_name.split(NAMESPACE_SEPARATOR[@language]) : [fully_qualified_name]
  end

  def get_file_path(root, namespace_array, file)
    namespace_array = [] unless JAVALANG == @language
    dir = File.join(root, *namespace_array)
    FileUtils.mkdir_p(dir)
    File.join(dir, file)
  end

  def get_base_name(name)
    namespace_array = get_name_array(name)
    base_name = namespace_array.pop
    namespace_array = [] unless JAVALANG == @language
    if namespace_array.empty?
      base_name
    else
      File.join(namespace_array, base_name)
    end
  end

  def edit_library(session, args)
    if @test
      name = args.shift
      tmp_source = args.shift
      tmp_header = args.shift
    else
      name = args
    end
    name_array = get_name_array(name)
    namespace_array = name_array.dup
    base_name = namespace_array.pop
    files = []
    source = "#{base_name}.#{SOURCE_SUFFIX[@language]}"
    source_path = get_file_path(@directory, namespace_array,  source)
    files << source_path
    header = HEADER_SUFFIX[@language] ? "#{base_name}.#{HEADER_SUFFIX[@language]}" : nil
    if header
      header_path = get_file_path(@directory, namespace_array, header)
      files << header_path
    end
    if @test
      FileUtils.cp(tmp_source, source_path)
      if header
        raise "must specify header file in test for language #{@language}" unless tmp_header
        FileUtils.cp(tmp_header, header_path)
      end
    else
      make_library_file(session, LIBRARY_SOURCE_TEMPLATE[@language], source_path, name_array)
      if header
        make_library_file(session, LIBRARY_HEADER_TEMPLATE[@language], header_path, name_array)
      end
      unless system("#{get_editor} #{files.join(' ')}")
        unsuccessful_editor = ENV['EDTIOR']
        ENV['EDITOR'] = nil
        raise LibraryEditError.new("error editing #{files.join(' ')}: #{unsuccessful_editor} failed")
      end
    end
    object = compile_library(source_path)
    if files.inject {|m,f| m and File.exists?(f) }
      session.libraries << object
      session.libraries.uniq!
      session.header_lines << "#include \"#{header}\"" if header
      session.header_lines.uniq!
    else
      @out.puts "no library created"
    end
  end

  def rm_library(session, name)
    base_name = get_base_name(name)
    source = "#{base_name}.#{SOURCE_SUFFIX[@language]}"
    FileUtils.rm(File.join(@directory, source), :force=>true)
    if HEADER_SUFFIX[@language]
      header = "#{base_name}.#{HEADER_SUFFIX[@language]}"
      FileUtils.rm(File.join(@directory, header), :force=>true)
      session.header_lines.reject! { |hdr| /\"#{header}\"/.match(hdr) }
    end
    if OBJECT_SUFFIX[@language]
      object = "#{base_name}.#{OBJECT_SUFFIX[@language]}"
      FileUtils.rm(File.join(@directory, object), :force=>true)
      session.libraries.reject! { |obj| /\/#{object}$/.match(obj) }
    end
  end

  def line_complete?(line)
    return true if /\A\s*#/.match(line)
    @lexer.line_complete?(line)
  end

  def puts_output(output, last_output)
    if output.length >= last_output.length and last_output == output[0,last_output.length]
      @out.puts output[last_output.length,output.length]
    else
      @out.puts output
    end
  end

  def prompt_for_language
    print "Choose a language (#{LANGUAGES.join(' ')}): "
    input = gets.strip.downcase
    language = LANGUAGES.detect { |lang| input[0,3] == lang[0,3] }
    unless language
      raise "not an option: #{input}"
    end
    language
  end

  def initialize(args, opts={})
    @debug = opts[:debug]
    @test = opts[:test]
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

  def get_command(line)
    case line.strip
    when /^#args\s*/
      ["arguments", $']
    when /^#(a\w*)\s*/
      cmd, arg = $1, $'
      /^#{cmd}/.match("arguments") ? ["arguments", arg] : nil
    when /^#(c.*)$/
      cmd = $1
      /^#{cmd}/.match("class") ? ["class", nil] : nil
    when /^#(deb.*)$/
      cmd = $1
      /^#{cmd}/.match("debug") ? ["debug", nil] : nil
    when /^#(de.*)\s+(\d+)$/
      cmd, arg = $1, $2.to_i
      /^#{cmd}/.match("delete") ? ["delete", arg] : nil
    when /^#(di.*)\s+([\w.#+-]+)$/
      cmd, arg = $1, $2
      /^#{cmd}/.match("directory") ? ["directory", arg]: nil
    when /^#(hea.*)$/
      cmd = $1
      /^#{cmd}/.match("header") ? ["header", nil] : nil
    when /^#(hel.*)$/
      cmd = $1
      /^#{cmd}/.match("help") ? ["help", nil] : nil
    when /^#(i.*)\s+(["<].+[">])$/
      cmd, arg = $1, $2
      /^#{cmd}/.match("include") ? ["include", arg] : nil
    when /^#(lib.*)\s+([\w.:]+)/
      cmd, arg, rest = $1, $2, $'
      if @test
        args = [arg] + rest.split
        raise "must specify extra files when using lib in test" unless args.size > 1
        /^#{cmd}/.match("library") ? ["library", args] : nil
      else
        /^#{cmd}/.match("library") ? ["library", arg] : nil
      end
    when /^#(lis.*)$/
      cmd = $1
      /^#{cmd}/.match("list") ? ["list", nil] : nil
    when /^#(m.*)$/
      cmd = $1
      /^#{cmd}/.match("main") ? ["main", nil] : nil
    when /^#(rm-l.*)\s+([\w.]+)$/
      cmd, arg = $1, $2
      /^#{cmd}/.match("rm-library") ? ["rm-library", arg] : nil
    when /^#(remove-l.*)\s+([\w.]+)$/
      cmd, arg = $1, $2
         /^#{cmd}/.match("remove-library") ? ["rm-library", nil] : nil
    else
      [nil,nil]
    end
  end

  def process_command(session, line)
    cmd,cmd_arg = get_command(line)
    case cmd
    when 'arguments'
      session.arguments = cmd_arg
    when 'class'
      session.next_location = session.location = 'C'
    when 'debug'
      @debug = !@debug
    when 'delete'
      begin
        session.delete(cmd_arg)
        last_output = '' if 0 == session.size
      rescue
        @out.puts "couldn't delete line #{cmd_arg}: #{$!.message}"
      end
    when 'directory'
      set_directory(session, cmd_arg)
    when 'header'
      session.next_location = session.location = 'H'
    when 'help'
      help
    when 'include'
      begin
        if [JAVALANG, CSHARP].include?(@language)
          @out.puts "RCEL: #include not supported for #{@language.capitalize}"
        else
          @out.puts "DEBUG line #{line}" if @debug
          @out.puts "DEBUG cmd_arg #{cmd_arg}" if @debug
          new_session = session.dup
          # deduplication could be foiled by whitespace variation
          new_session.header_lines << line unless new_session.header_lines.include?(line)
          source = make_source(new_session)
          executable = compile_executable(source, new_session.libraries)
          session = new_session
        end
      rescue CompilationError
        @out.puts "RCEL: failed to include #{cmd_arg}"
      end
    when 'library'
      begin
        edit_library(session, cmd_arg)
      rescue CompilationError, LibraryEditError
        @out.puts "RCEL: failed to edit library"
      end
    when 'list'
      session.list(@out)
    when 'main'
      session.location = 'M'
    when 'rm-library'
      rm_library(session, cmd_arg)
    else
      @out.puts "RCEL: unrecognized command: #{line}"
    end
    return session, cmd
  end

  def process_line(session, line)
    begin
      new_session = session.dup
      new_session.add(line, session.location)
      source = make_source(new_session)
      executable = compile_executable(source, session.libraries)
      new_session.output = run_executable(executable, session.arguments)
      puts_output(new_session.output, session.output)
    rescue CompilationError, ExecutionError
      return session
    end
    new_session
  end

  def get_line(session)
    line = ''
    continued_line = false
    loop do
      if @in == $stdin
        part = readline("#{continued_line ? "#{session.location}..." : ("#{session.location}%03d" % (session.size + 1))}> ", true)
      else
        part = @in.gets
      end
      if part.nil?
        @out.puts
        return nil
      end
      line << part
      return  line if line_complete?(line)
      continued_line = true
    end
  end

  def set_directory(session, directory)
    @directory = directory
    FileUtils.mkdir_p @directory
    session.clear
    Dir.new(@directory).each { |f| session.libraries << File.join(@directory, f) if f.match(/#{OBJECT_SUFFIX[@language]}$/) }
    @out.puts "Using libraries: #{session.libraries.join(' ')}" unless session.libraries.empty?
    Dir.new(@directory).each { |f| session.header_lines << "#include \"#{f}\"" if f.match(/#{HEADER_SUFFIX[@language]}$/) } if HEADER_SUFFIX[@language]
    @out.puts "Using headers: #{session.header_lines.join(' ')}" unless session.header_lines.empty?
  end

  def get_location(line)
    first_word = line[/\A\s*(\w+)\b/,1]
    if  HEADER_KEYWORDS[@language].include?(first_word)
      'H'
    else
      ' '
    end
  end

  def repl(opts = {})
    raise "no language" unless @language
    raise "no directory" unless @directory
    @out = opts[:output] || $stdout
    @in = opts[:input] || $stdin
    @lexer = lexer(LEX_LANGUAGE[@language])
    session = Session.new(@language)
    set_directory(session, @directory)
    loop do
      cmd = nil
      begin
        line = get_line(session)
      rescue Clex::ParseError
        @out.puts "lexer reports that input doesn't lex: #{$!.message}"
        next
      end
      break if line.nil?
      if /\A\s*#/.match(line)
        session, cmd = process_command(session, line)
      else
        session.location = session.next_location || get_location(line)
        session = process_line(session, line)
        session.next_location = nil
      end
      session.location = ' ' unless ['class','header'].include?(cmd)
    end
  end
end

class Rcel
  class Session

    attr_accessor :header_lines, :class_lines, :main_lines, :libraries, :output, :location, :arguments, :next_location

    CLASS_TESTS_JAVA =
      [ lambda {|l| /\A\s*(public|protected|private)\s+enum\b/.match(l) },
      ]
    CLASS_TESTS_CSHARP =
      [ lambda {|l| /\A\s*(public\s+)?enum\b/.match(l) },
      ]

    def initialize(language)
      @language = language
      raise "unrecognized language #{@language}" unless LANGUAGES.include?(@language)
      clear
      @header_tests = []
      @class_tests = []
      case @language
      when JAVALANG
        @class_tests = CLASS_TESTS_JAVA
      when CSHARP
        @class_tests = CLASS_TESTS_CSHARP
      end
    end

    def clear
      @output = ''
      @location = ' '
      @libraries = []
      @header_lines = []
      @class_lines = []
      @main_lines = []
      @arguments = ''
    end

    def dup
      retval = Session.new(@language)
      retval.header_lines = @header_lines.dup
      retval.class_lines = @class_lines.dup
      retval.main_lines = @main_lines.dup
      retval.libraries = @libraries.dup
      retval.arguments = @arguments.dup
      retval
    end

    def size
      [@header_lines,@class_lines,@main_lines].inject(0) {|m,o| m+o.size }
    end

    def add(line, location)
      case location
      when ' '
        if @header_tests.inject(false) { |m,o| m or o.call(line) }
          @header_lines << line
        elsif @class_tests.inject(false) { |m,o| m or o.call(line) }
          @class_lines << line
        else
          @main_lines << line
        end
      when 'H'
        @header_lines << line
      when 'C'
        @class_lines << line
      when 'M'
        @main_ines << line
      else
        raise "unsupported location: #{location}"
      end
    end

    def list(fout=$stdout)
      lineno = 1
      [@header_lines, @class_lines, @main_lines].each do |a|
        a.each do |ll|
          ll.split("\n").each_with_index do |l,i|
            if 0 == i
              fout.puts "%03d> %s" % [ lineno, l]
            else
              fout.puts "...> %s" % l
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
  opts = {}
  ARGV.each do |arg|
    if /^--/.match(arg)
      opts[$'.to_sym] = true
    end
  end
  ARGV.reject! { |arg| /^--|rcel/.match(arg) }
  rcel = Rcel.new(ARGV, opts)
  rcel.language = rcel.prompt_for_language unless rcel.language
  rcel.directory = File.join(ENV['HOME'], "Lang/#{rcel.language.capitalize}/rcel-project") unless rcel.directory
  puts "Working in directory #{rcel.directory} using language #{rcel.language}.  Type #help to see list of commands."
  rcel.repl
end
