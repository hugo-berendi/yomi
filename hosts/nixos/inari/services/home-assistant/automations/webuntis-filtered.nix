{...}: {
  services.home-assistant.config = {
    template = [
      {
        trigger = [
          {
            platform = "time_pattern";
            minutes = "/5";
          }
          {
            platform = "homeassistant";
            event = "start";
          }
          {
            platform = "state";
            entity_id = "sensor.webuntis_next_lesson_to_wake_up";
          }
        ];
        action = [
          {
            action = "webuntis.get_timetable";
            data = {
              device_id = "{{ device_id('sensor.webuntis_next_lesson') }}";
              start = "{{ now().strftime('%Y-%m-%d') }}";
              end = "{{ (now() + timedelta(days=7)).strftime('%Y-%m-%d') }}";
              apply_filter = false;
              show_cancelled = false;
              compact_result = false;
            };
            response_variable = "timetable_response";
          }
        ];
        sensor = [
          {
            name = "WebUntis My Timetable";
            unique_id = "webuntis_my_timetable";
            state = ''
              {% set my_teachers = ["SP", "KT", "MM", "KO", "FR", "BU", "WA", "TO"] %}
              {% set conditional = {"LO": ["M"], "MÜ": ["WR"], "WJ": ["PuG"]} %}
              {% set lessons = timetable_response.lessons | default([]) %}
              {% set ns = namespace(count=0) %}
              {% for lesson in lessons %}
                {% set teacher = lesson.teachers[0].name if lesson.teachers else 'none' %}
                {% set subject = lesson.subjects[0].name if lesson.subjects else 'none' %}
                {% set is_mine = teacher in my_teachers %}
                {% if not is_mine and teacher in conditional %}
                  {% set is_mine = subject in conditional[teacher] %}
                {% endif %}
                {% if is_mine %}
                  {% set ns.count = ns.count + 1 %}
                {% endif %}
              {% endfor %}
              {{ ns.count }}
            '';
            unit_of_measurement = "lessons";
            icon = "mdi:filter-check";
            attributes = {
              lessons = ''
                {% set my_teachers = ["SP", "KT", "MM", "KO", "FR", "BU", "WA", "TO"] %}
                {% set conditional = {"LO": ["M"], "MÜ": ["WR"], "WJ": ["PuG"]} %}
                {% set lessons = timetable_response.lessons | default([]) %}
                {% set ns = namespace(filtered=[]) %}
                {% for lesson in lessons %}
                  {% set teacher = lesson.teachers[0].name if lesson.teachers else 'none' %}
                  {% set subject = lesson.subjects[0].name if lesson.subjects else 'none' %}
                  {% set is_mine = teacher in my_teachers %}
                  {% if not is_mine and teacher in conditional %}
                    {% set is_mine = subject in conditional[teacher] %}
                  {% endif %}
                  {% if is_mine %}
                    {% set ns.filtered = ns.filtered + [lesson] %}
                  {% endif %}
                {% endfor %}
                {{ ns.filtered | to_json }}
              '';
              teachers = "SP, KT, MM, KO, FR, BU, WA, TO, LO (M only), MÜ (WR only), WJ (PuG only)";
            };
          }
        ];
      }
      {
        sensor = [
          {
            name = "WebUntis My Lessons Today";
            unique_id = "webuntis_my_lessons_today";
            state = ''
              {% set lessons = state_attr('sensor.webuntis_my_timetable', 'lessons') | default('[]') | from_json %}
              {% set today = now().strftime('%Y-%m-%d') %}
              {% set ns = namespace(count=0) %}
              {% for lesson in lessons %}
                {% if lesson.start[:10] == today %}
                  {% set ns.count = ns.count + 1 %}
                {% endif %}
              {% endfor %}
              {{ ns.count }}
            '';
            unit_of_measurement = "lessons";
            icon = "mdi:school";
            attributes = {
              lessons = ''
                {% set lessons = state_attr('sensor.webuntis_my_timetable', 'lessons') | default('[]') | from_json %}
                {% set today = now().strftime('%Y-%m-%d') %}
                {% set ns = namespace(filtered=[]) %}
                {% for lesson in lessons %}
                  {% if lesson.start[:10] == today %}
                    {% set ns.filtered = ns.filtered + [lesson] %}
                  {% endif %}
                {% endfor %}
                {{ ns.filtered | to_json }}
              '';
              schedule = ''
                {% set lessons = state_attr('sensor.webuntis_my_timetable', 'lessons') | default('[]') | from_json %}
                {% set today = now().strftime('%Y-%m-%d') %}
                {% set ns = namespace(lines=[]) %}
                {% for lesson in lessons | sort(attribute='start') %}
                  {% if lesson.start[:10] == today %}
                    {% set time = lesson.start | as_datetime | as_local | as_timestamp | timestamp_custom('%H:%M') %}
                    {% set subj = lesson.subjects[0].long_name if lesson.subjects else 'Free' %}
                    {% set room = lesson.rooms[0].name if lesson.rooms else 'TBD' %}
                    {% set teacher = lesson.teachers[0].name if lesson.teachers else '-' %}
                    {% set ns.lines = ns.lines + [time ~ ' ' ~ subj ~ ' (' ~ room ~ ') - ' ~ teacher] %}
                  {% endif %}
                {% endfor %}
                {{ ns.lines | join('\n') }}
              '';
            };
          }
          {
            name = "WebUntis My Next Lesson";
            unique_id = "webuntis_my_next_lesson";
            state = ''
              {% set lessons = state_attr('sensor.webuntis_my_timetable', 'lessons') | default('[]') | from_json %}
              {% set now_ts = now() | as_timestamp %}
              {% set ns = namespace(next=none) %}
              {% for lesson in lessons | sort(attribute='start') %}
                {% set start_ts = lesson.start | as_datetime | as_timestamp %}
                {% if start_ts > now_ts and ns.next is none %}
                  {% set ns.next = lesson %}
                {% endif %}
              {% endfor %}
              {% if ns.next %}
                {% set subj = ns.next.subjects[0].long_name if ns.next.subjects else 'Unknown' %}
                {{ subj }}
              {% else %}
                No lessons
              {% endif %}
            '';
            icon = "mdi:calendar-clock";
            attributes = {
              start = ''
                {% set lessons = state_attr('sensor.webuntis_my_timetable', 'lessons') | default('[]') | from_json %}
                {% set now_ts = now() | as_timestamp %}
                {% set ns = namespace(next=none) %}
                {% for lesson in lessons | sort(attribute='start') %}
                  {% set start_ts = lesson.start | as_datetime | as_timestamp %}
                  {% if start_ts > now_ts and ns.next is none %}
                    {% set ns.next = lesson %}
                  {% endif %}
                {% endfor %}
                {{ ns.next.start if ns.next else 'unknown' }}
              '';
              room = ''
                {% set lessons = state_attr('sensor.webuntis_my_timetable', 'lessons') | default('[]') | from_json %}
                {% set now_ts = now() | as_timestamp %}
                {% set ns = namespace(next=none) %}
                {% for lesson in lessons | sort(attribute='start') %}
                  {% set start_ts = lesson.start | as_datetime | as_timestamp %}
                  {% if start_ts > now_ts and ns.next is none %}
                    {% set ns.next = lesson %}
                  {% endif %}
                {% endfor %}
                {{ ns.next.rooms[0].name if ns.next and ns.next.rooms else 'unknown' }}
              '';
              teacher = ''
                {% set lessons = state_attr('sensor.webuntis_my_timetable', 'lessons') | default('[]') | from_json %}
                {% set now_ts = now() | as_timestamp %}
                {% set ns = namespace(next=none) %}
                {% for lesson in lessons | sort(attribute='start') %}
                  {% set start_ts = lesson.start | as_datetime | as_timestamp %}
                  {% if start_ts > now_ts and ns.next is none %}
                    {% set ns.next = lesson %}
                  {% endif %}
                {% endfor %}
                {{ ns.next.teachers[0].long_name if ns.next and ns.next.teachers else 'unknown' }}
              '';
              time = ''
                {% set lessons = state_attr('sensor.webuntis_my_timetable', 'lessons') | default('[]') | from_json %}
                {% set now_ts = now() | as_timestamp %}
                {% set ns = namespace(next=none) %}
                {% for lesson in lessons | sort(attribute='start') %}
                  {% set start_ts = lesson.start | as_datetime | as_timestamp %}
                  {% if start_ts > now_ts and ns.next is none %}
                    {% set ns.next = lesson %}
                  {% endif %}
                {% endfor %}
                {% if ns.next %}
                  {{ ns.next.start | as_datetime | as_local | as_timestamp | timestamp_custom('%H:%M') }}
                {% else %}
                  unknown
                {% endif %}
              '';
            };
          }
          {
            name = "WebUntis My First Lesson";
            unique_id = "webuntis_my_first_lesson";
            device_class = "timestamp";
            state = ''
              {% set lessons = state_attr('sensor.webuntis_my_timetable', 'lessons') | default('[]') | from_json %}
              {% set tomorrow = (now() + timedelta(days=1)).strftime('%Y-%m-%d') if now().hour >= 14 else now().strftime('%Y-%m-%d') %}
              {% set ns = namespace(first=none) %}
              {% for lesson in lessons | sort(attribute='start') %}
                {% if lesson.start[:10] >= tomorrow and ns.first is none %}
                  {% set ns.first = lesson %}
                {% endif %}
              {% endfor %}
              {{ ns.first.start if ns.first else 'unknown' }}
            '';
            icon = "mdi:alarm";
            attributes = {
              subject = ''
                {% set lessons = state_attr('sensor.webuntis_my_timetable', 'lessons') | default('[]') | from_json %}
                {% set tomorrow = (now() + timedelta(days=1)).strftime('%Y-%m-%d') if now().hour >= 14 else now().strftime('%Y-%m-%d') %}
                {% set ns = namespace(first=none) %}
                {% for lesson in lessons | sort(attribute='start') %}
                  {% if lesson.start[:10] >= tomorrow and ns.first is none %}
                    {% set ns.first = lesson %}
                  {% endif %}
                {% endfor %}
                {{ ns.first.subjects[0].long_name if ns.first and ns.first.subjects else 'unknown' }}
              '';
              room = ''
                {% set lessons = state_attr('sensor.webuntis_my_timetable', 'lessons') | default('[]') | from_json %}
                {% set tomorrow = (now() + timedelta(days=1)).strftime('%Y-%m-%d') if now().hour >= 14 else now().strftime('%Y-%m-%d') %}
                {% set ns = namespace(first=none) %}
                {% for lesson in lessons | sort(attribute='start') %}
                  {% if lesson.start[:10] >= tomorrow and ns.first is none %}
                    {% set ns.first = lesson %}
                  {% endif %}
                {% endfor %}
                {{ ns.first.rooms[0].name if ns.first and ns.first.rooms else 'unknown' }}
              '';
              teacher = ''
                {% set lessons = state_attr('sensor.webuntis_my_timetable', 'lessons') | default('[]') | from_json %}
                {% set tomorrow = (now() + timedelta(days=1)).strftime('%Y-%m-%d') if now().hour >= 14 else now().strftime('%Y-%m-%d') %}
                {% set ns = namespace(first=none) %}
                {% for lesson in lessons | sort(attribute='start') %}
                  {% if lesson.start[:10] >= tomorrow and ns.first is none %}
                    {% set ns.first = lesson %}
                  {% endif %}
                {% endfor %}
                {{ ns.first.teachers[0].name if ns.first and ns.first.teachers else 'unknown' }}
              '';
            };
          }
          {
            name = "WebUntis My Wake Time";
            unique_id = "webuntis_my_wake_time";
            state = ''
              {% set first = states('sensor.webuntis_my_first_lesson') %}
              {% if first not in ['unknown', 'unavailable'] %}
                {{ (as_datetime(first) - timedelta(hours=1, minutes=20)) | as_timestamp | timestamp_custom('%H:%M', true) }}
              {% else %}
                unknown
              {% endif %}
            '';
            icon = "mdi:alarm";
          }
          {
            name = "WebUntis My Prep Time";
            unique_id = "webuntis_my_prep_time";
            state = ''
              {% set first = states('sensor.webuntis_my_first_lesson') %}
              {% if first not in ['unknown', 'unavailable'] %}
                {{ (as_datetime(first) - timedelta(minutes=40)) | as_timestamp | timestamp_custom('%H:%M', true) }}
              {% else %}
                unknown
              {% endif %}
            '';
            icon = "mdi:clock-outline";
          }
        ];
      }
    ];

    automation = [
      {
        id = "webuntis_filtered_wake_up";
        alias = "WebUntis Filtered Wake-Up";
        description = "Sunrise alarm based on filtered school schedule (my teachers only)";
        trigger = [
          {
            platform = "template";
            value_template = "{{ now().strftime('%H:%M') == states('sensor.webuntis_my_wake_time') }}";
          }
        ];
        condition = [
          {
            condition = "state";
            entity_id = "person.hugo_berendi";
            state = "home";
          }
          {
            condition = "template";
            value_template = "{{ states('sensor.webuntis_my_wake_time') not in ['unknown', 'unavailable'] }}";
          }
          {
            condition = "time";
            weekday = ["mon" "tue" "wed" "thu" "fri"];
          }
        ];
        action = [
          {
            action = "light.turn_on";
            target.entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
            data = {
              brightness_pct = 5;
              color_temp_kelvin = 2200;
            };
          }
          {
            delay = "00:02:00";
          }
          {
            action = "light.turn_on";
            target.entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
            data = {
              brightness_pct = 20;
              color_temp_kelvin = 3000;
              transition = 180;
            };
          }
          {
            delay = "00:03:00";
          }
          {
            action = "light.turn_on";
            target.entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
            data = {
              brightness_pct = 60;
              color_temp_kelvin = 4000;
              transition = 120;
            };
          }
        ];
        mode = "single";
      }
      {
        id = "webuntis_filtered_leave_reminder";
        alias = "WebUntis Filtered Leave Reminder";
        description = "Reminder to leave for school (filtered schedule)";
        trigger = [
          {
            platform = "template";
            value_template = "{{ now().strftime('%H:%M') == states('sensor.webuntis_my_prep_time') }}";
          }
        ];
        condition = [
          {
            condition = "state";
            entity_id = "person.hugo_berendi";
            state = "home";
          }
          {
            condition = "template";
            value_template = "{{ states('sensor.webuntis_my_prep_time') not in ['unknown', 'unavailable'] }}";
          }
        ];
        action = [
          {
            action = "notify.mobile_app_hotei";
            data = {
              title = "Time to Leave!";
              message = ''
                First lesson in 40 minutes: {{ state_attr('sensor.webuntis_my_first_lesson', 'subject') }}
                Room: {{ state_attr('sensor.webuntis_my_first_lesson', 'room') }}
                Teacher: {{ state_attr('sensor.webuntis_my_first_lesson', 'teacher') }}
                {% if is_state('binary_sensor.id_3_charging_cable_connected', 'on') %}
                Don't forget to unplug the car!
                {% endif %}
              '';
              data = {
                tag = "leave_reminder";
                priority = "high";
              };
            };
          }
        ];
        mode = "single";
      }
      {
        id = "webuntis_filtered_lesson_change";
        alias = "WebUntis Filtered Lesson Change";
        description = "Notify when a lesson with my teachers changes";
        trigger = [
          {
            platform = "state";
            entity_id = "event.webuntis_lesson_change";
          }
        ];
        condition = [
          {
            condition = "template";
            value_template = ''
              {% set event = trigger.to_state.attributes %}
              {% set my_teachers = ["SP", "KT", "MM", "KO", "FR", "BU", "WA", "TO", "LO", "MÜ", "WJ"] %}
              {% set old_teacher = event.old_lesson.teachers[0].name if event.old_lesson and event.old_lesson.teachers else 'none' %}
              {% set new_teacher = event.new_lesson.teachers[0].name if event.new_lesson and event.new_lesson.teachers else 'none' %}
              {{ old_teacher in my_teachers or new_teacher in my_teachers }}
            '';
          }
        ];
        action = [
          {
            action = "notify.all_devices";
            data = {
              title = "My Lesson Changed";
              message = ''
                {% set event = trigger.to_state.attributes %}
                {% set event_type = event.event_type | default('unknown') %}
                {% if event_type == 'cancelled' %}
                CANCELLED: {{ event.old_lesson.subjects[0].long_name if event.old_lesson.subjects else 'Unknown' }}
                Time: {{ event.old_lesson.start | as_datetime | as_local | as_timestamp | timestamp_custom('%a %H:%M') }}
                Teacher: {{ event.old_lesson.teachers[0].name if event.old_lesson.teachers else 'Unknown' }}
                {% elif event_type == 'rooms' %}
                ROOM CHANGE: {{ event.new_lesson.subjects[0].long_name if event.new_lesson.subjects else 'Unknown' }}
                New room: {{ event.new_lesson.rooms[0].name if event.new_lesson.rooms else 'TBD' }}
                {% elif event_type == 'teachers' %}
                TEACHER CHANGE: {{ event.new_lesson.subjects[0].long_name if event.new_lesson.subjects else 'Unknown' }}
                New teacher: {{ event.new_lesson.teachers[0].long_name if event.new_lesson.teachers else 'TBD' }}
                {% else %}
                Schedule change ({{ event_type }}). Check WebUntis.
                {% endif %}
              '';
              data = {
                priority = "high";
                ttl = 0;
                tag = "lesson_change";
              };
            };
          }
        ];
        mode = "queued";
        max = 10;
      }
    ];
  };
}
