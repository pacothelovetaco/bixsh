# Shell
#
# Terminal emulator
#
# I could not have done this without this great resource from Jesse Storimer
# http://www.jstorimer.com/blogs/workingwithcode/7766107-a-unix-shell-in-ruby
#
# @author Justin Leavitt
#
# @since 0.0.1
require "socket"
require 'shellwords'
require 'readline'
require 'open3'
require 'json'

module BixsbyShell
  class Shell
    
    ##
    # Ruby doesn't handle all bash commands natively. This is a list of
    # commands that simulate those commands
    BUILTINS = {
      'cd' => lambda { |dir| Dir.chdir(dir) },
      'exit' => lambda { |code = 0| exit(code.to_i) },
      'exec' => lambda { |*command| exec *command },
      'set' => lambda { |args| 
        key, value = args.split('=') 
        ENV[key] = value
      }
    }
    
    ##
    # When interacting with Bixsby, some words are translated as bash commands.
    # This list bans those commands so they are sent to Bixsby instead.
    BANNED = [
      "yes",
      "what",
      "more"
    ]
    
    def parse_response(bixsby_server_response)
      bixsby_response = JSON.parse(bixsby_server_response)
      session_id      = bixsby_response["session_id"]
      message         = bixsby_response["response"]

      @session_id = session_id if @session_id.nil?
      message
    end

    def package_response(input)
      {
        session_id: @session_id, 
        input: input
      }.to_json
    end

    def execute_command(line, console_type)
      commands = split_on_pipes(line)

      placeholder_in = $stdin
      placeholder_out = $stdout
      pipe = []

      commands.each_with_index do |command, index|
        program, *arguments = Shellwords.shellsplit(command)

        if builtin?(program)
          if program == 'exit'
            @server.close
          end
          call_builtin(program, *arguments)
        else
          if index + 1 < commands.size
            pipe = IO.pipe
            placeholder_out = pipe.last
          else
            placeholder_out = $stdout
          end
          
          if console_type == :simple
            spawn_program_simple(program, *arguments, placeholder_out, placeholder_in)
          else
            spawn_program_gui(program, *arguments, placeholder_out, placeholder_in)
          end

          placeholder_out.close unless placeholder_out == $stdout
          placeholder_in.close unless placeholder_in == $stdin
          placeholder_in = pipe.first
        end
      end
      Process.waitall 
    end

    def split_on_pipes(line)
      line.scan( /([^"'|]+)|["']([^"']+)["']/ ).flatten.compact
    end

    def builtin?(program)
      BUILTINS.has_key?(program)
    end

    def banned?(program)
      BANNED.include?(program)
    end

    def call_builtin(program, *arguments)
      BUILTINS[program].call(*arguments)
      rescue => e
        input = arguments.unshift(program).join(" ")
        @server.puts(input)
    end

    def spawn_program_simple(program, *arguments, placeholder_out, placeholder_in)
      fork {
        unless placeholder_out == $stdout
          $stdout.reopen(placeholder_out)
          placeholder_out.close
        end

        unless placeholder_in == $stdin
          $stdin.reopen(placeholder_in)
          placeholder_in.close
        end
        
        begin
          raise "Program is a banned program" if banned?(program)
          exec(program, *arguments)
        rescue => e
          input = arguments.unshift(program).join(" ")
          bixsby_formatted_input = package_response(input)
          
          @server.puts(bixsby_formatted_input)
          response = @server.gets.chomp

          message = parse_response(response)
          display_simple_response(message)
        end
      }
    end

    def spawn_program_gui(program, *arguments, placeholder_out, placeholder_in)
      unless placeholder_out == $stdout
        $stdout.reopen(placeholder_out)
        placeholder_out.close
      end

      unless placeholder_in == $stdin
        $stdin.reopen(placeholder_in)
        placeholder_in.close
      end
      
      begin
        raise "Program is a banned program" if banned?(program)
        captured_stdout = ''
        captured_stderr = ''
        exit_status = Open3.popen3(program, *arguments) {|stdin, stdout, stderr, wait_thr|
          pid = wait_thr.pid # pid of the started process.
          stdin.close
          captured_stdout = stdout.read
          captured_stderr = stderr.read
          wait_thr.value # Process::Status object returned.
        }
        if exit_status.success?
          @panel1.printw("%s",  captured_stdout.strip)
          @panel1.refresh
        else
          @panel1.printw("%s",  captured_stdout.strip)
          @panel1.refresh
        end
          @panel1.printw("\n")
          @panel1.refresh
      rescue => e
        input = arguments.unshift(program).join(" ")
        bixsby_formatted_input = package_response(input)
        @server.puts(bixsby_formatted_input)
      end
    end

    def colorize(text, color_code)
      "\e[#{color_code}m#{text}\e[0m"
    end

    def red(text); colorize(text, 31); end
    def green(text); colorize(text, 32); end
    def yellow(text); colorize(text, 33); end
    def blue(text); colorize(text, 34); end
    def magenta(text); colorize(text, 35); end
    def cyan(text); colorize(text, 36); end
  end
end
