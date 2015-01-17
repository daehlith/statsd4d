/*
 * Copyright (c) 2015 Thomas Daehling <doc@methedrine.org>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
module statsd;

// StatsD Metrics Export Specification v0.1: https://github.com/b/statsd_spec
// etsy's statsd definition: https://github.com/etsy/statsd/blob/master/docs/metric_types.md

// default server port: 8125

// suggested payload sizes for network classifications:
//  - Fast Ethernet: 1432
//  - Gigabit Ethernet: 8932
//  - Commodity Internet: 512

// type info: gauges are 32 bit floats, while counters are 64 bit ints [citation needed]

import std.random : uniform;
import std.socket : Address, getAddress, UdpSocket;

class StatsClient(SocketType = UdpSocket)
{
	/**
	* Create a StatsClient instance.
	* 
	* Params:
	*      host = the host on which the statsd server runs, defaults to "localhost".
	*      port = the port on which the statsd server runs, defaults to 8125.
	*      prefix = an optional prefix for stats recorded with this StatsClient instance.
	*      mtu = the maximum transmissions size, defaults to 512 which is reasonable for UDP packets on commodity internet.
	*/
	this(string host="localhost", ushort port=8125, string prefix="", size_t mtu=512)
	{
		this(getAddress(host, port)[0], prefix, mtu);
	}

	/**
	* Create a StatsClient instance.
	*
	* Params:
	*      addr = the address at which the statsd server runs.
	*      prefix = an optional prefix for stats recorded with this StatsClient instance.
	*      mtu = the maximum transmission size, defaults to 512 which is reasonable for UDP packets on commodity internet.
	*/
	this(Address addr, string prefix="", size_t mtu=512)
	{
		socket.connect(addr);
		this.prefix = prefix;
		this.mtu = mtu;
	}

	Pipeline pipeline()
	{
		return new Pipeline(this);
	}

	Timer timer()
	{
		return new Timer(this);
	}

	void incr(string stat, count=1, rate=1)
	{
		sendStat(stat, count.stringof~"|c", rate);
	}

	void decr(string stat, count=1, rate=1)
	{
		sendStat(stat, -count, rate);
	}

	void gauge(string stat, int value, float rate=1, bool delta=false)
	{
		// to set a gauge to a negative value, one must first specify set it to 0.
		if ( value < 0 && ! delta )
		{
			if (rate < uniform(0.0, 1.0))
			{
				return;
			}
			// send as pipeline:
			//  sendStat(stat, "0|g", 1)
			// 	sendStat(stat, value.stringof~"|g", 1);
		}
		else
		{
			char prefix = delta > 0 && value >= 0 ? "+" : "";
			sendStat(stat, prefix~value.stringof~"|g", rate);
		}
	}

	void set(string stat, int value, float rate=1)
	{
		sendStat(stat, value.stringof~"|s", rate);
	}

	void timing(string stat, int delta, float rate=1)
	{
		sendStat(stat, delta.stringof~"|ms", rate);
	}

	private void sendStat(string stat, int value, float rate)
	{
		if ( rate < 1.0 && uniform(0.0f, 1.0f) > rate)
		{
			return;
		}

		if ( this.prefix )
		{
			stat = prefix ~ "." ~ stat;
		}

		stat ~= ":"~value.stringof;
		socket.send(stat);
	}

	size_t mtu = 512;
	string prefix = "";

	private SocketType socket;
}

class Pipeline
{
};

class Timer
{
};

// 
unittest
{
	// Poor man's mock socket class, specificially the connect and send methods, and check within those for expected values.
	class TestSocket
	{
		void connect(Address addr)
		{
		}
	}

	auto testClient = new StatsClient!TestSocket;
	assert(testClient.mtu == 512);
	assert(testClient.prefix == "");
}