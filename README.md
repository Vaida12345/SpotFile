# SpotFile
This software is similar to Spotlight, but it focuses exclusively on files.

With this app, you can specify names for different paths, and use such names for searching.

## Example
In this setup, you could use `app` to search the application directory. (This page can be reached by pressing the `Settings...` button)

<img width="1058" alt="Screenshot 2024-07-24 at 9 12 13 AM" src="https://github.com/user-attachments/assets/98a8830d-cf3b-4b38-984e-a53b42c818d4">


Then, in the menu bar, as you type `app`,

<img width="344" alt="Screenshot 2024-07-24 at 9 09 14 AM" src="https://github.com/user-attachments/assets/02c609a1-070c-4ad6-be5f-18ac8f09cde9">

You can then hit enter to open the application folder.

## Search inside a folder
If you enable the `Enable deep search` in the `app` setup, you could search inside the application folder. Then, when you type `app spot`, it would search for the keyword `spot` within the application folder.

<img width="344" alt="Screenshot 2024-07-24 at 9 11 24 AM" src="https://github.com/user-attachments/assets/92bc488d-7b3a-47c2-8244-ffe36de74fa5">

## Matching

This app uses the similar matching rule to Xcode:
- prefix matching (`spot` for `SpotFile`)
- use initials (`cc` for `CameraCapture`)
- case insensitive
- skip components (`file` for `SpotFile`)

As you use the app, this app could learn from your habits, and adjust the order in which the results are shown to you.

> This process works as follows: whenever you open a file within this app, i.e., when the search is complete, the app records the query you used to locate the file. In subsequent searches, if your new query is a prefix of a previously recorded query, the app will prioritize displaying the associated file. 

## Privacy

This app does not require an internet connection, and no data leaves your device. Consequently, neither the developer nor Apple will have access to any of your information.
