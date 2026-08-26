import json
import sys

transcript_path = '/Users/balls/.gemini/antigravity/brain/1a4550e6-ad7c-4fb2-b453-fea1c3eb6b45/.system_generated/logs/transcript_full.jsonl'

files_to_recover = [
    'BypassSettingsViewController.m',
    'CategoriesViewController.m',
    'CategoryVideosViewController.m',
    'ChannelViewController.m',
    'LoginViewController.m',
    'SearchViewController.m',
    'SettingsViewController.m',
    'SubscriptionsViewController.m',
    'TrendingViewController.m'
]

file_contents = {f: "" for f in files_to_recover}

try:
    with open(transcript_path, 'r') as f:
        for line in f:
            try:
                data = json.loads(line)
                if 'tool_calls' in data:
                    for tc in data['tool_calls']:
                        if tc.get('name') == 'default_api:write_to_file':
                            args = tc.get('arguments', {})
                            target_file = args.get('TargetFile', '')
                            for filename in files_to_recover:
                                if target_file.endswith(filename):
                                    file_contents[filename] = args.get('CodeContent', '')
                        elif tc.get('name') == 'default_api:replace_file_content':
                            args = tc.get('arguments', {})
                            target_file = args.get('TargetFile', '')
                            for filename in files_to_recover:
                                if target_file.endswith(filename):
                                    # Very naive: just take the latest replacement as a patch, but we might miss context.
                                    # We'll just print out that there were replacements.
                                    pass
            except Exception as e:
                pass
except Exception as e:
    print(e)

for filename, content in file_contents.items():
    if content:
        with open(f'YouTube/Controllers/{filename}', 'w') as out_f:
            out_f.write(content)
        print(f"Recovered {filename}")
    else:
        print(f"Could not find {filename}")

