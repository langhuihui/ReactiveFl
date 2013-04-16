package reactivefl.concurrency
{
	import reactivefl.i.IDisposable;

	public class ImmediateScheduler extends Scheduler
	{
		public function ImmediateScheduler()
		{
			super();
		}
		override protected function scheduleNow(state:*, action:Function):IDisposable{
			return action(this,state);
		}
		override protected function scheduleRelative(state:*, dueTime:Number, action:Function):IDisposable{
			if (dueTime > 0) throw new Error(schedulerNoBlockError);
			return action(this, state);
		}
		override protected function scheduleAbsolute(state:*, dueTime:Number, action:Function):IDisposable{
			return scheduleWithRelativeAndState(state, dueTime - immediate.now(), action);
		}
	}
}