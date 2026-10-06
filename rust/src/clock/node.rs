use godot::classes::{INode, Node};
use godot::prelude::*;

use super::{GameClock, Season, TimeOfDay};

/// Godot-facing wrapper around [`GameClock`]. Add as an autoload so every
/// system can read the time and connect to its signals.
#[derive(GodotClass)]
#[class(base=Node)]
pub struct GameClockNode {
    /// Game minutes per real second (1.0 => 1 real minute = 1 game hour).
    #[export]
    #[var]
    time_scale: f64,
    #[export]
    #[var]
    paused: bool,
    /// Fast-forward multiplier (1, 2, 4...).
    #[export]
    #[var]
    speed_multiplier: f64,
    #[export(range = (1.0, 9999.0, 1.0))]
    start_year: i64,
    #[export(range = (1.0, 12.0, 1.0))]
    start_month: i64,
    #[export(range = (1.0, 30.0, 1.0))]
    start_day: i64,
    #[export(range = (0.0, 23.0, 1.0))]
    start_hour: i64,
    /// When off, the season never changes and day length is fixed.
    #[export]
    #[var]
    seasons_enabled: bool,
    /// Season used while `seasons_enabled` is off.
    #[export(enum = (Spring, Summer, Autumn, Winter))]
    #[var]
    fixed_season: i64,

    clock: GameClock,
    last_season: Season,
    last_time_of_day: TimeOfDay,
    last_speed: f64,
    last_paused: bool,
    base: Base<Node>,
}

#[godot_api]
impl INode for GameClockNode {
    fn init(base: Base<Node>) -> Self {
        let clock = GameClock::default();
        Self {
            time_scale: clock.time_scale,
            paused: false,
            speed_multiplier: 1.0,
            start_year: 1,
            start_month: 1,
            start_day: 1,
            start_hour: 8,
            seasons_enabled: true,
            fixed_season: Season::Spring.index(),
            last_season: clock.season(),
            last_time_of_day: clock.time_of_day(),
            last_speed: 1.0,
            last_paused: false,
            clock,
            base,
        }
    }

    fn ready(&mut self) {
        self.sync_settings();
        self.clock.set_date_time(
            self.start_year.max(1) as u64,
            self.start_month.max(1) as u64,
            self.start_day.max(1) as u64,
            self.start_hour.max(0) as u64,
            0,
        );
        self.last_season = self.clock.season();
        self.last_time_of_day = self.clock.time_of_day();
        self.last_speed = self.speed_multiplier;
        self.last_paused = self.paused;
    }

    fn process(&mut self, delta: f64) {
        // Compared every frame so inspector / direct property writes notify too.
        if self.speed_multiplier != self.last_speed || self.paused != self.last_paused {
            self.last_speed = self.speed_multiplier;
            self.last_paused = self.paused;
            let (speed, paused) = (self.speed_multiplier, self.paused);
            self.signals().speed_changed().emit(speed, paused);
        }
        self.sync_settings();
        let events = self.clock.advance(delta);

        if events.minutes_passed > 0 {
            self.signals().minute_changed().emit();
        }
        if events.hour_changed {
            let hour = self.clock.hour() as i64;
            self.signals().hour_changed().emit(hour);
        }
        if events.day_changed {
            let day_of_year = self.clock.day_of_year() as i64;
            self.signals().day_changed().emit(day_of_year);
        }
        if events.year_changed {
            let year = self.clock.year() as i64;
            self.signals().year_changed().emit(year);
        }

        // Compared every frame so toggling `seasons_enabled` also notifies.
        let season = self.clock.season();
        if season != self.last_season {
            self.last_season = season;
            self.signals().season_changed().emit(season.index());
        }
        let tod = self.clock.time_of_day();
        if tod != self.last_time_of_day {
            self.last_time_of_day = tod;
            self.signals().time_of_day_changed().emit(tod.index());
        }
    }
}

#[godot_api]
impl GameClockNode {
    #[signal]
    fn minute_changed();
    #[signal]
    fn hour_changed(hour: i64);
    #[signal]
    fn day_changed(day_of_year: i64);
    #[signal]
    fn year_changed(year: i64);
    /// 0 Spring, 1 Summer, 2 Autumn, 3 Winter.
    #[signal]
    fn season_changed(season: i64);
    /// 0 Night, 1 Dawn, 2 Day, 3 Dusk.
    #[signal]
    fn time_of_day_changed(time_of_day: i64);
    /// Emitted when the speed multiplier or the paused state changes.
    #[signal]
    fn speed_changed(speed: f64, paused: bool);

    #[func]
    fn get_minute(&self) -> i64 {
        self.clock.minute() as i64
    }

    #[func]
    fn get_hour(&self) -> i64 {
        self.clock.hour() as i64
    }

    /// Day of the month, 1-based.
    #[func]
    fn get_day(&self) -> i64 {
        self.clock.day() as i64
    }

    /// Month, 1-based.
    #[func]
    fn get_month(&self) -> i64 {
        self.clock.month() as i64
    }

    #[func]
    fn get_year(&self) -> i64 {
        self.clock.year() as i64
    }

    #[func]
    fn get_day_of_year(&self) -> i64 {
        self.clock.day_of_year() as i64
    }

    /// 0..7
    #[func]
    fn get_weekday(&self) -> i64 {
        self.clock.weekday() as i64
    }

    /// 0 Spring, 1 Summer, 2 Autumn, 3 Winter.
    #[func]
    fn get_season(&self) -> i64 {
        self.clock.season().index()
    }

    /// 0 Night, 1 Dawn, 2 Day, 3 Dusk.
    #[func]
    fn get_time_of_day(&self) -> i64 {
        self.clock.time_of_day().index()
    }

    /// 0.0 night .. 1.0 full daylight; drive lights / CanvasModulate with it.
    #[func]
    fn get_daylight(&self) -> f32 {
        self.clock.daylight()
    }

    /// Fractional hour, 0.0..24.0.
    #[func]
    fn get_hour_float(&self) -> f32 {
        self.clock.hour_f32()
    }

    #[func]
    fn get_time_string(&self) -> GString {
        self.clock.time_string().as_str().into()
    }

    #[func]
    fn is_night(&self) -> bool {
        self.clock.time_of_day() == TimeOfDay::Night
    }

    #[func]
    fn set_speed(&mut self, multiplier: f64) {
        self.speed_multiplier = multiplier.max(0.0);
    }

    #[func]
    fn set_paused_state(&mut self, paused: bool) {
        self.paused = paused;
    }

    /// Jump to a time within the current year (`day_of_year` is 0-based).
    #[func]
    fn set_time(&mut self, day_of_year: i64, hour: i64, minute: i64) {
        self.clock.set_time(
            day_of_year.max(0) as u64,
            hour.max(0) as u64,
            minute.max(0) as u64,
        );
    }

    /// Jump to an exact date and time (year, month, day are 1-based).
    #[func]
    fn set_date(&mut self, year: i64, month: i64, day: i64, hour: i64, minute: i64) {
        self.clock.set_date_time(
            year.max(1) as u64,
            month.max(1) as u64,
            day.max(1) as u64,
            hour.max(0) as u64,
            minute.max(0) as u64,
        );
    }

    /// Opaque value for save files; restore with `load_total_minutes`.
    #[func]
    fn get_total_minutes(&self) -> i64 {
        self.clock.total_minutes() as i64
    }

    #[func]
    fn load_total_minutes(&mut self, total_minutes: i64) {
        self.clock.set_total_minutes(total_minutes.max(0) as u64);
    }

    fn sync_settings(&mut self) {
        self.clock.time_scale = self.time_scale;
        self.clock.paused = self.paused;
        self.clock.speed_multiplier = self.speed_multiplier;
        self.clock.seasons_enabled = self.seasons_enabled;
        self.clock.fixed_season = Season::from_index(self.fixed_season);
    }
}
