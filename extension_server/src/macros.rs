#[macro_export]
macro_rules! lock {
    ($mutex:expr) => {{
        use rand::prelude::*;

        let mut rng = rand::thread_rng();
        let delay: u64 = rng.gen_range(1..250_000);

        let mut container: Option<parking_lot::MutexGuard<_>> = None;
        while container.is_none() {
            std::thread::sleep(std::time::Duration::from_nanos(delay));
            container = $mutex.try_lock()
        }

        container.unwrap()
    }};
}
