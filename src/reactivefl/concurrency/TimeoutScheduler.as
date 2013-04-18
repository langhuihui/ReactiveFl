package reactivefl.concurrency
{
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	
	import reactivefl.disposables.CompositeDisposable;
	import reactivefl.disposables.Disposable;
	import reactivefl.disposables.SingleAssignmentDisposable;
	import reactivefl.i.IDisposable;

	public class TimeoutScheduler extends Scheduler
	{
		public function TimeoutScheduler()
		{
			super();
		}
		override protected function scheduleNow(state:*, action:Function):IDisposable {
			var disposable:SingleAssignmentDisposable = new SingleAssignmentDisposable();
			var id:uint = setTimeout(function () {
				disposable.setDisposable(action(this, state));
			},0);
			return new CompositeDisposable(disposable, Disposable.create(function () {
				clearTimeout(id);
			}));
		}
		
		override protected function scheduleRelative(state:*, dueTime:Number, action:Function):IDisposable {
			var dt:Number = Scheduler.normalize(dueTime);
			if (dt === 0) {
				return scheduleWithState(state, action);
			}
			var disposable:SingleAssignmentDisposable = new SingleAssignmentDisposable();
			var id:uint = setTimeout(function () {
				disposable.setDisposable(action(this, state));
			}, dt);
			return new CompositeDisposable(disposable, Disposable.create(function () {
				clearTimeout(id);
			}));
		}
		
		override protected function scheduleAbsolute(state:*, dueTime:Number, action:Function):IDisposable {
			return this.scheduleWithRelativeAndState(state, dueTime - this.now(), action);
		}
	}
}