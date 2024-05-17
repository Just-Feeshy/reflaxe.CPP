package;

import cxx.std.Thread;
import cxx.std.Duration;

function thread_func(thread_id:Int):Void {
    trace("Thread " + thread_id + " with ID" + Thread.getID() + " started");
	final sleep_time:Duration = 2;
    Thread.sleep(sleep_time.toSeconds());
	trace("Thread " + thread_id + " with ID" + Thread.getID() + " finished");
}

function main() {
    final thread_count:Int = 5;

	var array:Array<Thread> = new Array<Thread>(thread_count);

	for (i in 0...thread_count) {
		array[i] = new Thread(thread_func);
	}

	for (i in 0...thread_count) {
		if(array[i].joinable()) {
			trace("Thread " + array[i].getID() + " joined");
			array[i].join();
		}
	}

	var cores = Thread.hardwareConcurrency();
	trace("Number of cores: " + cores);
}
