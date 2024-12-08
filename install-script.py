import os
import shutil
import stat
import tkinter as tk
from tkinter import filedialog, messagebox

def is_git_repository(folder_path):
    """Check if the selected folder is a Git repository."""
    return os.path.isdir(os.path.join(folder_path, ".git"))

def set_executable_permission(file_path):
    """Set executable permissions on a file."""
    st = os.stat(file_path)
    os.chmod(file_path, st.st_mode | stat.S_IEXEC)

def main():
    root = tk.Tk()
    root.withdraw() 

    folder_path = filedialog.askdirectory(title="Select a Git Repository Folder")
    
    if not folder_path:
        messagebox.showinfo("Installation Aborted", "No folder selected.")
        return
    
    if not is_git_repository(folder_path):
        messagebox.showerror("Error", "The selected folder is not a Git repository.")
        return
    
    hooks_dir = os.path.join(folder_path, ".git", "hooks")
    hook_file = os.path.join(os.getcwd(), "post-commit.sh")
    target_hook_file = os.path.join(hooks_dir, "post-commit")

    if not os.path.isfile(hook_file):
        messagebox.showerror("Error", f"Hook file 'post-commit.sh' not found in {os.getcwd()}.")
        return
    
    try:
        shutil.copyfile(hook_file, target_hook_file)
        set_executable_permission(target_hook_file)
        messagebox.showinfo("Success", f"Hook installed successfully in '{target_hook_file}'.")
    except Exception as e:
        messagebox.showerror("Error", f"Failed to install hook: {e}")

if __name__ == "__main__":
    main()
