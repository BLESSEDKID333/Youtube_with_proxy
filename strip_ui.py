import os
import glob

controllers = glob.glob('YouTube/Controllers/*.m')

for path in controllers:
    with open(path, 'r') as f:
        lines = f.readlines()
        
    out = []
    skip = False
    for i, line in enumerate(lines):
        if "respondsToSelector:@selector(setBarTintColor:)" in line and "navigationBar" in line:
            skip = True
        elif skip and "}" in line and "]" not in line and "navigationBar" not in line and "COLOR_" not in line:
            # End of if block
            pass
        elif "navigationBar.tintColor =" in line or "navigationBar.translucent =" in line or "setTitleTextAttributes:" in line or "@{UITextAttributeTextColor:" in line:
            pass
        elif "respondsToSelector:@selector(setTranslucent:)" in line:
            skip = True
        elif skip and "}" in line:
            skip = False
        elif skip:
            pass
        elif "self.view.backgroundColor = COLOR_LIGHT_BG;" in line:
            # Change background to white or default group table bg
            if "Grouped" in "".join(lines) or "Settings" in path or "Login" in path:
                out.append(line.replace("COLOR_LIGHT_BG", "[UIColor groupTableViewBackgroundColor]"))
            else:
                out.append(line.replace("COLOR_LIGHT_BG", "[UIColor whiteColor]"))
        elif "self.tableView.backgroundColor =" in line:
            if "Grouped" in "".join(lines) or "Settings" in path or "Login" in path:
                out.append(line.replace("COLOR_LIGHT_BG", "[UIColor groupTableViewBackgroundColor]"))
            else:
                out.append(line.replace("COLOR_LIGHT_BG", "[UIColor whiteColor]"))
        else:
            out.append(line)
            
    with open(path, 'w') as f:
        f.writelines(out)

# Also fix MainTabBarController
with open('YouTube/Controllers/MainTabBarController.m', 'r') as f:
    tb = f.read()
tb = tb.replace('[[UITabBar appearance] setTintColor:COLOR_YOUTUBE_RED];', '')
tb = tb.replace('self.tabBar.tintColor = COLOR_YOUTUBE_RED;', '')
tb = tb.replace('[self.tabBar setValue:[UIColor colorWithRed:30.0/255.0 green:30.0/255.0 blue:30.0/255.0 alpha:1.0] forKey:@"barTintColor"];', '')
with open('YouTube/Controllers/MainTabBarController.m', 'w') as f:
    f.write(tb)
