# StartFromTray

**English** | [Русский](README.ru.md)

StartFromTray is a portable Windows tray launcher for applications, documents, folders, and scripts.

It keeps your frequently used commands in a customizable hierarchical menu available from the system tray. Each menu item supports three actions: run it, edit its target, or quickly open its settings.

## Mouse controls

| Mouse button | Action                                                               |
| ------------ | -------------------------------------------------------------------- |
| Left         | Run or open the selected item                                        |
| Right        | Edit the target using a configured editor or the Windows edit action |
| Middle       | Open the selected item in the StartFromTray configuration window     |

This is especially useful for scripts: you can run a script with the left mouse button and open it in an editor with the right mouse button.

## Features

* Organize commands into a hierarchical menu with nested groups.
* Launch applications, documents, folders, scripts, and other Windows shell targets.
* Specify command-line parameters for each item.
* Run commands or editors with administrator privileges.
* Copy, rename, reorder, and move items using the configuration tree.
* Apply changes immediately or discard all unsaved changes.
* Assign icons automatically or select them from `.exe`, `.dll`, and `.ico` files.
* Use an icon associated with a chosen file extension.
* Start StartFromTray automatically with Windows.
* See whether a process launched by an item is still running.
* Avoid launching the same item again while its process is still running.
* Mark commands whose target files cannot be found.
* Find executable files through the Windows `App Paths` registry entries and the `PATH` environment variable.

## Custom Run and Edit actions

StartFromTray lets you define separate **Run** and **Edit** applications for selected file extensions.

For example, you can:

* run `.ps1` files with PowerShell and edit them in Visual Studio Code;
* run a script with custom parameters;
* use different editors for different file types;
* add custom file-type filters to the file selection dialog.

Run and Edit applications can have their own command-line parameters. The `:(command)` placeholder can be used to specify the exact position of the selected file in the parameter string.

If no custom Edit action is configured, StartFromTray uses the Windows file association. If no editor is associated with the file, StartFromTray opens File Explorer and selects the file.

## Portable operation

StartFromTray does not require installation. Its menu, extension rules, language files, and application settings are stored in files next to the executable.

Keep the application in a folder where your Windows account has write access. The entire folder can then be copied to another location or backed up.

## Language support

The interface supports external language files stored in the `Langs` directory. New translations can be added without recompiling the application.

StartFromTray is a native Windows application written in Delphi using VCL.