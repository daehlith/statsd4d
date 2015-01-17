What is statsd4d ?
------------------

statsd4d is a [statsd](https://github.com/etsy/statsd/) client for the [D programming language](http://www.dlang.org/). It has been heavily inspired by the [statsd python package](https://github.com/jsocol/pystatsd).

Usage
-----

Quickly, to use:
>>> import statsd;
>>> c = statsd.StatsClient(); // connect to a statsd server running on 'localhost' at the default port 8125.
>>> c.incr('foo'); // increment the 'foo' counter.
>>> c.timing('stats.timed', 320); // Record a 320 ms 'stats.timed'.

You can also prefix all your stats:
>>> import statsd;
>>> c = statsd.StatsClient('localhost', 8125, 'foo');
>>> c.incr('bar'); // Will be 'foo.bar' in statsd/graphite.

Building
--------

statsd4d is provided as a [dub](http://code.dlang.org/about/) package and as such all its standard operations are supported. Compiled binaries are located in the .build subfolder.
