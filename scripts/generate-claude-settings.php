#!/usr/bin/env php
<?php
// #ddev-generated
// Generate Claude Code settings.json with hooks configuration

$options = getopt('', ['url-allowlist:', 'env-protection:', 'output:']);

$urlAllowlist = ($options['url-allowlist'] ?? 'true') === 'true';
$envProtection = ($options['env-protection'] ?? 'true') === 'true';
$outputFile = $options['output'] ?? null;

if (!$outputFile) {
    fwrite(STDERR, "Error: --output is required\n");
    exit(1);
}

$hooksPath = '"$HOME"/.claude/hooks';

$settings = [
    'hooks' => [
        'PreToolUse' => [],
        'PostToolUse' => [],
    ],
];

if ($urlAllowlist) {
    foreach (['WebFetch', 'Bash'] as $tool) {
        $settings['hooks']['PreToolUse'][] = [
            'matcher' => $tool,
            'hooks' => [[
                'type' => 'command',
                'command' => "$hooksPath/url-allowlist-check.sh",
                'timeout' => 10,
                'statusMessage' => 'Checking URL allowlist...',
            ]],
        ];
        $settings['hooks']['PostToolUse'][] = [
            'matcher' => $tool,
            'hooks' => [[
                'type' => 'command',
                'command' => "$hooksPath/url-allowlist-add.sh",
                'timeout' => 5,
            ]],
        ];
    }
}

if ($envProtection) {
    // Read tool
    $settings['hooks']['PreToolUse'][] = [
        'matcher' => 'Read',
        'hooks' => [[
            'type' => 'command',
            'command' => "$hooksPath/env-protection.sh",
            'timeout' => 5,
            'statusMessage' => 'Checking file access...',
        ]],
    ];

    // Add to Bash if exists, otherwise create
    $envHook = [
        'type' => 'command',
        'command' => "$hooksPath/env-protection.sh",
        'timeout' => 5,
        'statusMessage' => 'Checking command safety...',
    ];

    $bashEntryIndex = null;
    foreach ($settings['hooks']['PreToolUse'] as $index => $entry) {
        if ($entry['matcher'] === 'Bash') {
            $bashEntryIndex = $index;
            break;
        }
    }

    if ($bashEntryIndex !== null) {
        array_unshift($settings['hooks']['PreToolUse'][$bashEntryIndex]['hooks'], $envHook);
    } else {
        $settings['hooks']['PreToolUse'][] = [
            'matcher' => 'Bash',
            'hooks' => [$envHook],
        ];
    }
}

$json = json_encode($settings, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
file_put_contents($outputFile, $json);
