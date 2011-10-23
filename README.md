
A RCEL (read compile execute loop) for C, C#, C++, Java, and Objective C

How to use it:

    ruby /PATH/TO/REPO/rcel.rb

For added convenience put an executable file called 'rcel' in
your search path with the following contents:

    #!/usr/bin/env sh
    exec /PATH/TO/REPO/rcel.rb $@
