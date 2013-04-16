package reactivefl.core
{
	import reactivefl.concurrency.Scheduler;
	import reactivefl.i.IDisposable;
	import reactivefl.i.IObserver;

	public class AnonymousObservable extends Observable
	{
		public function AnonymousObservable(subscribe:Function)
		{
			var s:Function = function (observer:IObserver):IDisposable {
				var autoDetachObserver:AutoDetachObserver = new AutoDetachObserver(observer);
				if (Scheduler.currentThread.scheduleRequired) {
					Scheduler.currentThread.schedule(function ():void {
						try {
							autoDetachObserver.disposable(subscribe(autoDetachObserver));
						} catch (e:Error) {
							if (!autoDetachObserver.fail(e)) {
								throw e;
							} 
						}
					});
				} else {
					try {
						autoDetachObserver.disposable(subscribe(autoDetachObserver));
					} catch (e:Error) {
						if (!autoDetachObserver.fail(e)) {
							throw e;
						}
					}
				}
				return autoDetachObserver;
			};
			super(s);
		}
	}
}