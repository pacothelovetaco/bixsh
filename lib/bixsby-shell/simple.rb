# Simple Shell
#
# @author Justin Leavitt
#
# @since 0.0.1
module BixsbyShell
  class Simple < Shell

    READLINE_PROMPT = "bixsby > "
    
    def initialize(server)
      @server = server
      run_simple_shell
    end

    def run_simple_shell
      message = parse_response(@server.gets.chomp)
      display_simple_response(message)
      while buffer = Readline.readline("#{READLINE_PROMPT}", true) 
        line = buffer.chomp.strip
        execute_command(line, :simple)
      end
    end
    
    def display_simple_response(message)
      puts self.blue "==\n#{message}\n=="
    end
  end
end
