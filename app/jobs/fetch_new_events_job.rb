class FetchNewEventsJob < ApplicationJob
  queue_as :high

  # This fetches new workouts in every users' calendars.
  def perform
    return unless Rails.env.production?
    User.joins(:preference).where.not(preferences: { id: nil }).find_each do |user|
      user.todays_calendar_events.each do |event|
        # Find any playlists already created for this workout today.
        activity = user.activity_for_calendar_event(event[:name])

        next if activity.present?

        activity = user.activities.create!( name: event[:name], description: event[:description], duration: event[:duration])
        Playlist.create!(user_id: user.id, activity_id: activity.id, music_request_id: user.current_music_request.id, processing: true)

        # Enqueue a job to generate the rest of the details with ChatGPT.
        GenerateActivityDetailsJob.perform_async(user.id, activity.id)
      end
    end
  end
end