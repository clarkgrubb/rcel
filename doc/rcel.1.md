% RCEL(1)
% Clark Grubb
% May 17, 2013


# NAME

rcel - Read-Compile-Evaluate-Loop for C, C++, C#, Java, and Objective-C

# SYNOPSIS

rcel [LANGUAGE [PROJECT_DIR]]

# DESCRIPTION

Simulate a REPL for the languages C, C++, C#, Java, and Objective-C.

`rcel` collects statements.  Each time a statement is entered, all
statements are compiled and executed.  This is done so that variables
can be set and then accessed in later statements.

The output from the previous run is remembered and removed, so it that
the user is given the impression that `rcel` is actually a REPL.  Printing
out random numbers or timestamps will defeat this mechanism, however.  Also,
interacting with the file system is likely to be confusing and error-prone.

By default `rcel` will put the source code it generates in `~/Lang/LANG/rcel-project`.
You can specify a different project directory on the command line.

To define a function in C, use the #class directive.  Here is an example:

     001> #class
    C001> int add(int x, int y) {
    C...>   return x + y;
    C...> }

     002> printf("19 + 23 = %d\n", add(19, 23));
    19 + 23 = 42

For a full list of the directives which are available, type
 `#help` at the `rcel` prompt.

# OPTIONS

None.

# SEE ALSO

`gcc` (1), `java` (1), `javac` (1), `mono` (1)

