//! Pure game clock: no Godot types, so it can be unit-tested with `cargo test`.
//!
//! Calendar: 60 min/hour, 24 h/day, 30 days/month, 12 months/year (360-day year).
//! Seasons are 90 days each and the year starts on the first day of spring.

pub mod node;

pub const MINUTES_PER_HOUR: u64 = 60;
pub const HOURS_PER_DAY: u64 = 24;
pub const DAYS_PER_MONTH: u64 = 30;
pub const MONTHS_PER_YEAR: u64 = 12;
pub const DAYS_PER_YEAR: u64 = DAYS_PER_MONTH * MONTHS_PER_YEAR;
pub const DAYS_PER_SEASON: u64 = DAYS_PER_YEAR / 4;
pub const MINUTES_PER_DAY: u64 = MINUTES_PER_HOUR * HOURS_PER_DAY;
pub const DAYS_PER_WEEK: u64 = 7;

/// Hours (fractional) over which dawn / dusk fade, centred on sunrise / sunset.
const TWILIGHT_HALF_WIDTH: f32 = 1.0;
/// Sunrise / sunset used when seasons are disabled.
const FIXED_SUNRISE: f32 = 6.0;
const FIXED_SUNSET: f32 = 20.0;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Season {
    Spring,
    Summer,
    Autumn,
    Winter,
}

impl Season {
    pub fn from_index(index: i64) -> Self {
        match index.rem_euclid(4) {
            0 => Season::Spring,
            1 => Season::Summer,
            2 => Season::Autumn,
            _ => Season::Winter,
        }
    }

    pub fn index(self) -> i64 {
        self as i64
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TimeOfDay {
    Night,
    Dawn,
    Day,
    Dusk,
}

impl TimeOfDay {
    pub fn index(self) -> i64 {
        self as i64
    }
}

/// Calendar boundaries crossed by one call to [`GameClock::advance`].
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct ClockEvents {
    pub minutes_passed: u64,
    pub hour_changed: bool,
    pub day_changed: bool,
    pub year_changed: bool,
}

#[derive(Clone, Debug)]
pub struct GameClock {
    total_minutes: u64,
    /// Fractional game minutes not yet applied to `total_minutes`.
    accumulator: f64,
    /// Game minutes per real second (1.0 => 1 real minute = 1 game hour).
    pub time_scale: f64,
    /// Extra multiplier for fast-forward (1x/2x/4x).
    pub speed_multiplier: f64,
    pub paused: bool,
    pub seasons_enabled: bool,
    /// Season reported (and used for daylight) while seasons are disabled.
    pub fixed_season: Season,
}

impl Default for GameClock {
    fn default() -> Self {
        Self {
            total_minutes: 0,
            accumulator: 0.0,
            time_scale: 1.0,
            speed_multiplier: 1.0,
            paused: false,
            seasons_enabled: true,
            fixed_season: Season::Spring,
        }
    }
}

impl GameClock {
    /// Advance by `real_delta` seconds of real time.
    pub fn advance(&mut self, real_delta: f64) -> ClockEvents {
        if self.paused || real_delta <= 0.0 {
            return ClockEvents::default();
        }
        self.accumulator += real_delta * self.time_scale * self.speed_multiplier;
        let whole = self.accumulator.floor();
        if whole < 1.0 {
            return ClockEvents::default();
        }
        self.accumulator -= whole;

        let before = self.total_minutes;
        self.total_minutes += whole as u64;
        let after = self.total_minutes;

        ClockEvents {
            minutes_passed: after - before,
            hour_changed: before / MINUTES_PER_HOUR != after / MINUTES_PER_HOUR,
            day_changed: before / MINUTES_PER_DAY != after / MINUTES_PER_DAY,
            year_changed: before / (MINUTES_PER_DAY * DAYS_PER_YEAR)
                != after / (MINUTES_PER_DAY * DAYS_PER_YEAR),
        }
    }

    pub fn total_minutes(&self) -> u64 {
        self.total_minutes
    }

    /// Restore a saved time (also clears any partial minute).
    pub fn set_total_minutes(&mut self, total_minutes: u64) {
        self.total_minutes = total_minutes;
        self.accumulator = 0.0;
    }

    /// Jump to a time of day on `day_of_year` (0-based) within the current year.
    pub fn set_time(&mut self, day_of_year: u64, hour: u64, minute: u64) {
        let year_start = self.total_days() / DAYS_PER_YEAR * DAYS_PER_YEAR;
        let day = year_start + day_of_year.min(DAYS_PER_YEAR - 1);
        self.set_total_minutes(
            day * MINUTES_PER_DAY
                + hour.min(HOURS_PER_DAY - 1) * MINUTES_PER_HOUR
                + minute.min(MINUTES_PER_HOUR - 1),
        );
    }

    /// Jump to an exact date and time. Year, month and day are 1-based like
    /// the getters; out-of-range values are clamped.
    pub fn set_date_time(&mut self, year: u64, month: u64, day: u64, hour: u64, minute: u64) {
        let year_index = year.max(1) - 1;
        let month_index = month.clamp(1, MONTHS_PER_YEAR) - 1;
        let day_index = day.clamp(1, DAYS_PER_MONTH) - 1;
        let total_days = year_index * DAYS_PER_YEAR + month_index * DAYS_PER_MONTH + day_index;
        self.set_total_minutes(
            total_days * MINUTES_PER_DAY
                + hour.min(HOURS_PER_DAY - 1) * MINUTES_PER_HOUR
                + minute.min(MINUTES_PER_HOUR - 1),
        );
    }

    fn total_days(&self) -> u64 {
        self.total_minutes / MINUTES_PER_DAY
    }

    pub fn minute(&self) -> u64 {
        self.total_minutes % MINUTES_PER_HOUR
    }

    pub fn hour(&self) -> u64 {
        self.total_minutes / MINUTES_PER_HOUR % HOURS_PER_DAY
    }

    /// Day of the year, 0-based (0..360).
    pub fn day_of_year(&self) -> u64 {
        self.total_days() % DAYS_PER_YEAR
    }

    /// Day of the month, 1-based (1..=30).
    pub fn day(&self) -> u64 {
        self.day_of_year() % DAYS_PER_MONTH + 1
    }

    /// Month, 1-based (1..=12).
    pub fn month(&self) -> u64 {
        self.day_of_year() / DAYS_PER_MONTH + 1
    }

    /// Year, 1-based.
    pub fn year(&self) -> u64 {
        self.total_days() / DAYS_PER_YEAR + 1
    }

    /// Day of the week, 0-based (0..7).
    pub fn weekday(&self) -> u64 {
        self.total_days() % DAYS_PER_WEEK
    }

    pub fn season(&self) -> Season {
        if self.seasons_enabled {
            Season::from_index((self.day_of_year() / DAYS_PER_SEASON) as i64)
        } else {
            self.fixed_season
        }
    }

    /// Current time as fractional hours (0.0..24.0).
    pub fn hour_f32(&self) -> f32 {
        self.hour() as f32 + self.minute() as f32 / MINUTES_PER_HOUR as f32
    }

    /// (sunrise, sunset) in fractional hours. Days are longest at mid-summer
    /// (day 135) and shortest at mid-winter (day 315) when seasons are enabled.
    pub fn sun_hours(&self) -> (f32, f32) {
        if !self.seasons_enabled {
            return (FIXED_SUNRISE, FIXED_SUNSET);
        }
        let phase = (self.day_of_year() as f32 - 135.0) / DAYS_PER_YEAR as f32;
        let summerness = (phase * std::f32::consts::TAU).cos(); // 1 summer, -1 winter
        (6.5 - 1.5 * summerness, 19.0 + 2.0 * summerness)
    }

    pub fn time_of_day(&self) -> TimeOfDay {
        let (sunrise, sunset) = self.sun_hours();
        let h = self.hour_f32();
        if h < sunrise - TWILIGHT_HALF_WIDTH {
            TimeOfDay::Night
        } else if h < sunrise + TWILIGHT_HALF_WIDTH {
            TimeOfDay::Dawn
        } else if h < sunset - TWILIGHT_HALF_WIDTH {
            TimeOfDay::Day
        } else if h < sunset + TWILIGHT_HALF_WIDTH {
            TimeOfDay::Dusk
        } else {
            TimeOfDay::Night
        }
    }

    /// Light level 0.0 (night) to 1.0 (full day), smooth through dawn and dusk.
    pub fn daylight(&self) -> f32 {
        let (sunrise, sunset) = self.sun_hours();
        let h = self.hour_f32();
        let width = TWILIGHT_HALF_WIDTH * 2.0;
        let rising = smoothstep((h - (sunrise - TWILIGHT_HALF_WIDTH)) / width);
        let falling = smoothstep(((sunset + TWILIGHT_HALF_WIDTH) - h) / width);
        rising.min(falling)
    }

    pub fn time_string(&self) -> String {
        format!("{:02}:{:02}", self.hour(), self.minute())
    }
}

fn smoothstep(t: f32) -> f32 {
    let t = t.clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn clock_at(day_of_year: u64, hour: u64, minute: u64) -> GameClock {
        let mut c = GameClock::default();
        c.set_time(day_of_year, hour, minute);
        c
    }

    #[test]
    fn one_real_minute_is_one_game_hour() {
        let mut c = GameClock::default();
        let ev = c.advance(60.0);
        assert_eq!(ev.minutes_passed, 60);
        assert!(ev.hour_changed && !ev.day_changed);
        assert_eq!((c.hour(), c.minute()), (1, 0));
    }

    #[test]
    fn fractional_deltas_accumulate() {
        let mut c = GameClock::default();
        for _ in 0..59 {
            c.advance(0.5);
        }
        assert_eq!(c.total_minutes(), 29);
    }

    #[test]
    fn pause_and_speed() {
        let mut c = GameClock::default();
        c.paused = true;
        assert_eq!(c.advance(100.0), ClockEvents::default());
        c.paused = false;
        c.speed_multiplier = 4.0;
        assert_eq!(c.advance(15.0).minutes_passed, 60);
    }

    #[test]
    fn rollovers() {
        let mut c = clock_at(DAYS_PER_YEAR - 1, 23, 59);
        assert_eq!(c.year(), 1);
        let ev = c.advance(1.0);
        assert!(ev.hour_changed && ev.day_changed && ev.year_changed);
        assert_eq!((c.year(), c.month(), c.day(), c.hour(), c.minute()), (2, 1, 1, 0, 0));
    }

    #[test]
    fn large_delta_reports_boundaries_once() {
        let mut c = GameClock::default();
        let ev = c.advance(60.0 * 24.0 * 3.0 + 5.0);
        assert!(ev.day_changed && !ev.year_changed);
        assert_eq!(c.day(), 4);
    }

    #[test]
    fn seasons() {
        assert_eq!(clock_at(0, 0, 0).season(), Season::Spring);
        assert_eq!(clock_at(89, 0, 0).season(), Season::Spring);
        assert_eq!(clock_at(90, 0, 0).season(), Season::Summer);
        assert_eq!(clock_at(180, 0, 0).season(), Season::Autumn);
        assert_eq!(clock_at(359, 0, 0).season(), Season::Winter);
    }

    #[test]
    fn seasons_disabled_uses_fixed_season_and_hours() {
        let mut c = clock_at(200, 12, 0);
        c.seasons_enabled = false;
        c.fixed_season = Season::Summer;
        assert_eq!(c.season(), Season::Summer);
        assert_eq!(c.sun_hours(), (6.0, 20.0));
    }

    #[test]
    fn summer_days_longer_than_winter() {
        let (sr_s, ss_s) = clock_at(135, 12, 0).sun_hours();
        let (sr_w, ss_w) = clock_at(315, 12, 0).sun_hours();
        assert!((sr_s - 5.0).abs() < 0.01 && (ss_s - 21.0).abs() < 0.01);
        assert!((sr_w - 8.0).abs() < 0.01 && (ss_w - 17.0).abs() < 0.01);
    }

    #[test]
    fn time_of_day_and_daylight() {
        let mut c = clock_at(0, 0, 0);
        c.seasons_enabled = false;
        c.set_time(0, 2, 0);
        assert_eq!(c.time_of_day(), TimeOfDay::Night);
        assert_eq!(c.daylight(), 0.0);
        c.set_time(0, 6, 0);
        assert_eq!(c.time_of_day(), TimeOfDay::Dawn);
        c.set_time(0, 12, 0);
        assert_eq!(c.time_of_day(), TimeOfDay::Day);
        assert_eq!(c.daylight(), 1.0);
        c.set_time(0, 20, 0);
        assert_eq!(c.time_of_day(), TimeOfDay::Dusk);
        c.set_time(0, 23, 0);
        assert_eq!(c.time_of_day(), TimeOfDay::Night);

        // Monotonic rise through dawn.
        let mut last = -1.0;
        for m in 0..=120 {
            c.set_time(0, 5 + m / 60, m % 60);
            let d = c.daylight();
            assert!(d >= last);
            last = d;
        }
    }

    #[test]
    fn set_date_time_round_trips() {
        let mut c = GameClock::default();
        c.set_date_time(1950, 5, 15, 13, 45);
        assert_eq!(
            (c.year(), c.month(), c.day(), c.hour(), c.minute()),
            (1950, 5, 15, 13, 45)
        );
        assert_eq!(c.season(), Season::Summer);
    }

    #[test]
    fn set_date_time_clamps() {
        let mut c = GameClock::default();
        c.set_date_time(0, 99, 99, 99, 99);
        assert_eq!(
            (c.year(), c.month(), c.day(), c.hour(), c.minute()),
            (1, 12, 30, 23, 59)
        );
    }

    #[test]
    fn time_string_and_weekday() {
        let c = clock_at(8, 7, 5);
        assert_eq!(c.time_string(), "07:05");
        assert_eq!(c.weekday(), 1);
    }
}
