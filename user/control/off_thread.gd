## Runs a piece of work on a worker thread while the main thread keeps drawing frames (the loading picture, the game), and
## hands back its result: `var x = await OffThread.run(self, func(): return heavy())`. The work must touch no nodes in the
## tree and no servers: plain data only (a builder's `bake`, an import), with the nodes made from it after, on the main thread.
class_name OffThread
extends RefCounted


static func run(node: Node, work: Callable) -> Variant:
	var box := [null]  # (a lambda can't assign the caller's local; it can fill an array)
	var task := WorkerThreadPool.add_task(func(): box[0] = work.call(), false, "off-thread work")
	while not WorkerThreadPool.is_task_completed(task):
		await node.get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return box[0]
