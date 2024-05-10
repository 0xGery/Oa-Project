-- Handler to print game announcements directly in the terminal.
Handlers.add(
  "PrintAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function (msg)
    print(msg.Event .. ": " .. msg.Data)
 os  end
)