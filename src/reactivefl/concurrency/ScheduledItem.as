package reactivefl.concurrency
{
	import reactivefl.RFL;
	import reactivefl.disposables.SingleAssignmentDisposable;

	public class ScheduledItem
	{
		private var scheduler:Scheduler;
		private var state:*;
		private var action:Function;
		public var dueTime:Number;
		private var comparer:Function;
		public var disposable:SingleAssignmentDisposable;
		public function ScheduledItem(scheduler:Scheduler, state:*, action:Function, dueTime:Number, comparer:Function = null)
		{
			this.scheduler = scheduler;
			this.state = state;
			this.action = action;
			this.dueTime = dueTime;
			this.comparer = comparer || RFL.defaultSubComparer;
			this.disposable = new SingleAssignmentDisposable();
		}
		public function invoke ():void {
			this.disposable.disposable(this.invokeCore());
		};
		public function compareTo (other:ScheduledItem):int {
			return this.comparer(this.dueTime, other.dueTime);
		};
		public function isCancelled () :Boolean{
			return this.disposable.isDisposed;
		};
		public function invokeCore () :*{
			return this.action(this.scheduler, this.state);
		};
	}
}