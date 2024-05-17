package;

function thread_func() {
	trace("Thread " + Thread.currentThread().getID() + " started");
	trace("Thread " + Thread.currentThread().getID() + " finished");
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
