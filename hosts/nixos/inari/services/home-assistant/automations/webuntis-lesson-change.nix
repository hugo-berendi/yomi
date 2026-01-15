{...}: {
  services.home-assistant.config.automation = [
    {
      id = "webuntis_lesson_change_notification";
      alias = "WebUntis Lesson Change Notification";
      description = "Notify all devices when a lesson is changed, cancelled, or moved";
      trigger = [
        {
          platform = "state";
          entity_id = "event.webuntis_lesson_change";
        }
      ];
      condition = [
        {
          condition = "template";
          value_template = "{{ trigger.to_state.attributes.event_type is defined }}";
        }
      ];
      action = [
        {
          action = "notify.all_devices";
          data = {
            title = "Lesson Change";
            message = ''
              {% set event = trigger.to_state.attributes %}
              {% set event_type = event.event_type | default('unknown') %}
              {% if event_type == 'cancelled' %}
              CANCELLED: {{ event.old_lesson.subjects[0].long_name if event.old_lesson.subjects else 'Unknown subject' }}
              Time: {{ event.old_lesson.start | as_datetime | as_local | as_timestamp | timestamp_custom('%a %H:%M') }}
              {% elif event_type == 'rooms' %}
              ROOM CHANGE: {{ event.new_lesson.subjects[0].long_name if event.new_lesson.subjects else 'Unknown' }}
              New room: {{ event.new_lesson.rooms[0].name if event.new_lesson.rooms else 'TBD' }}
              {% elif event_type == 'teachers' %}
              TEACHER CHANGE: {{ event.new_lesson.subjects[0].long_name if event.new_lesson.subjects else 'Unknown' }}
              New teacher: {{ event.new_lesson.teachers[0].long_name if event.new_lesson.teachers else 'TBD' }}
              {% else %}
              Schedule change detected ({{ event_type }}). Check WebUntis for details.
              {% endif %}
            '';
            data = {
              priority = "high";
              ttl = 0;
            };
          };
        }
      ];
      mode = "queued";
      max = 10;
    }
  ];
}
