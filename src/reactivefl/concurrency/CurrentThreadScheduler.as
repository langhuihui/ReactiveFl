package reactivefl.concurrency
{
	import reactivefl.i.IDisposable;

	public class CurrentThreadScheduler extends Scheduler
	{
		private var trampoline:Trampoline;
		public function get scheduleRequired():Boolean{
			return trampoline == null || trampoline.queue == null;
		}
		public function ensureTrampoline(action:Function):IDisposable{
			if (scheduleRequired) {
				return this.schedule(action);
			} else {
				return action();
			}
		}
		override protected function scheduleNow(state:*, action:Function):IDisposable {
			return this.scheduleWithRelativeAndState(state, 0, action);
		}
		
		override protected function scheduleRelative(state:*, dueTime:Number, action:Function):IDisposable {
			var dt:Number = this.now() + Scheduler.normalize(dueTime),
				si:ScheduledItem = new ScheduledItem(this, state, action, dt);
			if (scheduleRequired) {
				trampoline = new Trampoline();
				try {
					trampoline.queue.enqueue(si);
					trampoline.run();
				} catch (e:Error) { 
					throw e;
				} finally {
					trampoline.dispose();
				}
			} else {
				trampoline.queue.enqueue(si);
			}
			return si.disposable;
		}
		
		override protected function scheduleAbsolute(state:*, dueTime:Number, action:Function):IDisposable {
			return this.scheduleWithRelativeAndState(state, dueTime - this.now(), action);
		}
		public function CurrentThreadScheduler()
		{
			super();
		}
	}
}
import reactivefl.concurrency.ScheduledItem;
import reactivefl.concurrency.Scheduler;
import reactivefl.i.IDisposable;
import reactivefl.internals.PriorityQueue;

class Trampoline implements IDisposable{
	public var queue:PriorityQueue;
	public function Trampoline(){
		queue = new PriorityQueue(4);
	}
	public function dispose():void{
		queue = null;
	}
	public function run():void{
		var item:ScheduledItem;
		while (queue.length > 0) {
			item = queue.dequeue();
			if (!item.isCancelled()) {
				while (item.dueTime - Scheduler.now() > 0) {
				}
				if (!item.isCancelled()) {
					item.invoke();
				}
			}
		}
	}
}