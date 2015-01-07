# GUI Shell
#
# Runs Bixsh in GUI mode. A lot of the code is incomplete because I am still
# learning Ncurses
#
# @author Justin Leavitt
#
# @since 0.0.1 
require 'ncurses'

module BixsbyShell
  class Gui < Shell
    
    def initialize(server)
      @server = server
      draw_interface
      listen_for_bixsby
      run_gui_shell
      @response.join
    end
    
    ##
    # Draws two Ncurses panels. The top panel (@panel1) is used to print responses 
    # while the bottom panel (@panel2) is used to capture commands.
    #
    # @return [Void]
    def draw_interface
      begin
        Ncurses.initscr
        Ncurses.cbreak
        Ncurses.noecho
        Ncurses.start_color

        Ncurses.init_pair 1, Ncurses::COLOR_WHITE, Ncurses::COLOR_BLUE
        Ncurses.init_pair 2, Ncurses::COLOR_GREEN, Ncurses::COLOR_WHITE
        
        # calculate panels sizes and locations
        rows, cols = [], []
        Ncurses.getmaxyx Ncurses.stdscr, rows, cols
        maxx = cols.first
        maxy = rows.first
        halfx = maxx / 2
        halfy = maxy / 2
        top = maxy - 3
        bottom = 3
        Ncurses.refresh
        
        # create 2 panels to take up the screen
        @panel1 = Ncurses.newwin top, maxx, 0, 0
        #panel1.bkgd Ncurses.COLOR_PAIR(1)
        @panel2 = Ncurses.newwin bottom, maxx, top, 0
        #panel2.bkgd Ncurses.COLOR_PAIR(2)
        if !@panel1
          Ncurses.addstr("Unable to allocate memory")
          Ncurses.refresh
        end  
        
        Ncurses.leaveok(@panel1, true)
        Ncurses.scrollok(@panel1, true)
        
        # write to each panel
        @panel1.refresh
        @panel2.refresh
        
        @panel2.keypad(true)
      ensure
        Ncurses.endwin
      end
    end

    ##
    # A clunky but somewhat functional implementation of readlines for @panel2.
    # Allows Ncurses to capture user input.
    #
    # @return [Void]
    def read_line(y, x, window = Ncurses.stdscr, max_len = (window.getmaxx - x - 1), string = "", cursor_pos = 0)
      window.clear
      window.border(*([0]*8))
      
      loop do
        window.mvaddstr(y,x,string)
        window.move(y,x+cursor_pos)
        ch = window.getch
        case ch
        when Ncurses::KEY_LEFT
          cursor_pos = [0, cursor_pos-1].max
        when Ncurses::KEY_RIGHT
          cursor_pos = [string.size,cursor_pos+1].min
        when Ncurses::KEY_ENTER, "\n".ord, "\r".ord
          cursor_pos = 0
          return string
        when Ncurses::KEY_BACKSPACE, 127
          string = string[0...([0, cursor_pos-1].max)] + string[cursor_pos..-1]
          cursor_pos = [0, cursor_pos-1].max
          window.mvaddstr(y, x+string.length, " ")
        when Ncurses::KEY_DC
          string = cursor_pos == string.size ? string : string[0...([0, cursor_pos].max)] + string[(cursor_pos+1)..-1]
          window.mvaddstr(y, x+string.length, " ")
        when 0..255 # remaining printables
          if string.size < (max_len - 1)
            string[cursor_pos,0] = ch.chr
            cursor_pos += 1
          end
        when Ncurses::KEY_UP
          # needs to be implemented, moves the screen up
        else
          #Ncurses.beep
        end
      end
      endad_line
    end
    
    
    ##
    # Opens a loop that listens for responses from the server. Prints the response
    # to @panel2 when one is received.
    # 
    # @return [Thread]
    def listen_for_bixsby
      @response = Thread.new do
        loop do
          response = @server.gets.chomp

          message = parse_response(response)
          @panel1.printw(" Bixsby: %s\n", message)
          @panel1.refresh
        end
      end
    end
    
    ##
    # Opens a loop to accept user input from @panel2.
    #
    # @return [Void]
    def run_gui_shell
      begin
       loop do
        line = read_line(1,2, @panel2)
        execute_command(line, :gui)
       end
      ensure
        Ncurses.endwin
      end
    end
  end
end
