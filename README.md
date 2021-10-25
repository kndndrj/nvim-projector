Some basic configs:

```
M.configurations.global.debug.go = {
  {
    type = 'go',
    name = 'Debug Current File',
    request = 'launch',
    showLog = false,
    program = '${file}',
    dlvToolPath = vim.fn.exepath('dlv'),
  },
  {
    type = 'go',
    name = 'Debug Test',
    request = 'launch',
    mode = 'test',
    showLog = false,
    program = '${file}',
    dlvToolPath = vim.fn.exepath('dlv'),
  },
}

M.configurations.global.tasks.shell = {
  {
    type = 'shell',
    name = 'CAT',
    command = 'cat',
    args = {
      '${workspaceFolder}/.vscode/launch.json',
      '|',
      'grep',
      'e',
    },
    program = '${file}',
    dlvToolPath = vim.fn.exepath('dlv'),
  },
  {
    type = 'shell',
    name = 'read',
    command = 'read',
    args = {
      'i;',
      'echo',
      '$i',
    },
  },
  {
    type = 'shell',
    name = 'ls',
    command = 'ls',
    args = {
      '-al',
    },
    cwd = '/home/andrej/',
  },
}


M.configurations.project.debug.go = {
  {
    type = 'go',
    name = 'Debug Current File project',
    request = 'launch',
    showLog = false,
    program = '${file}',
    dlvToolPath = vim.fn.exepath('dlv'),
  },
  {
    type = 'go',
    name = 'Debug Test project',
    request = 'launch',
    mode = 'test',
    showLog = false,
    program = '${file}',
    dlvToolPath = vim.fn.exepath('dlv'),
  },
}

M.configurations.project.tasks.shell = {
  {
    type = 'shell',
    name = 'CAT project',
    command = 'echo',
    args = {
      '$TEST_ENV',
      '$TEST_ENV2',
    },
    env = {
      TEST_ENV = "test",
      TEST_ENV2 = "test2",
    }
  },
}
```
