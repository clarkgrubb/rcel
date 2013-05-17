# SUMMARY

A RCEL (read compile execute loop) for C, C#, C++, Java, and Objective C

# SETUP

`rcel` expects `gcc`, `java`, and `mono` to be installed.

To install `rcel` in `INSTALL_DIR` (or by default, `/usr/local/bin`), run

    $ make install

# HOW TO RUN

    $ rcel

Here is an example session:

    $ rcel
    Choose a language (c c# java objective-c c++ fortran95 pascal): c
    Working in directory /Users/clark/Lang/C/rcel-project using language c.  Type #help to see list of commands.
     001> #help
    #arguments         Set the command line arguments.  Type them separated by whitespace as
                       if you were invoking the command from a shell.  The arguments are
                       available in the array variable argv.  In C, C++, and Objective C the
                       size of the array is in argc.
    #class             Put the following line outside the main method, but inside class body.
                       For C, C++, and Objective C, the line is put outside the main function
                       and after the header lines.
    #delete  <LINE_NO> Delete the indicated line number
    #dir     <DIR>     Change to indicated directory.  This clears the session.
    #header            Put the following line outside the class body.  For C, C++, and
                       Objective C, the line goes ahead of all function definitions.
    #help              Display this menu
    #include <HEADER>  Include the indicated header file.
    #library <LIBRARY> Edit the indicated library.
    #list              List all header lines, class lines, and main lines.
    #main              Put the following line inside the main method.  Normally it is not
                       necessary to specify this; will override built-in logic for determing
                       line position.
    #rm-lib  <LIBRARY> Remove the indicated library.
     001> int i = 7;

     002> printf("i is %d\n", i);
    i is 7
     003> ^D

# FILES

`rcel` will create these directories:

* `~/Lang/C/rcel-project`
* `~/Lang/C++/rcel-project`
* `~/Lang/C#/rcel-project`
* `~/Lang/Java/rcel-project`
* `~/Lang/Objective-C/rcel-project`