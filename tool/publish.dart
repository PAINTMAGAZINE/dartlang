part of atom.grind;

@Task('Publish a new major version of dartlang')
publishMajor() => _publish('major');

@Task('Publish a new minor version of dartlang')
publishMinor() => _publish('minor');

@Task('Publish a new patch version of dartlang')
publishPatch() => _publish('patch');

_publish(String publishType) {
  // Command line parsing (major, minor, patch) version update.
  if (publishType != 'major' && publishType != 'minor' && publishType != 'patch') {
    fail('Invalid publish type: ${publishType}');
  }
  // Comment out the if statements while developing this task.
  var diffResult = Process.runSync("git", ["diff", "--shortstat"]);
  if (diffResult.stdout.toString().isNotEmpty)
    throw 'Index is dirty; commit files and try again';

  var syncResult = Process.runSync("git", ["rev-list", "origin..HEAD"]);
  if (syncResult.stdout.toString().isNotEmpty)
    throw 'Not synchronized with master; git push and try again';

  var packageFileData = new File('package.json').readAsStringSync();
  var yamlFileData    = new File('pubspec.yaml').readAsStringSync();
  var changelogData   = new File('CHANGELOG.md').readAsStringSync();

  var packageData = JSON.decode(packageFileData);

  var currentVersion = new Version.parse(packageData['version']);
  var nextVersion;
  if (publishType == 'major') nextVersion = currentVersion.nextMajor;
  if (publishType == 'minor') nextVersion = currentVersion.nextMinor;
  if (publishType == 'patch') nextVersion = currentVersion.nextPatch;

  // We do pattern matches to preserve the formatting in the existing files.
  var jsonPattern         = (version) => '"version": "${version}"';
  var yamlPattern         = (version) => 'version: ${version}';
  var changelogPattern    = (version) => "# ${version}";

  if (!changelogData.contains('## unreleased')) {
    fail("Please add a '## unreleased' section to the changelog.");
  }

  var newPackageFileData =
    packageFileData.replaceFirst(jsonPattern(currentVersion),
      jsonPattern(nextVersion));
  var newYamlFileData =
    yamlFileData.replaceFirst(yamlPattern(currentVersion),
      yamlPattern(nextVersion));
  var newChangelogData =
    changelogData.replaceFirst(changelogPattern('unreleased'),
      changelogPattern(nextVersion));

  new File('package.json').writeAsStringSync(newPackageFileData);
  new File('pubspec.yaml').writeAsStringSync(newYamlFileData);
  new File('CHANGELOG.md').writeAsStringSync(newChangelogData);

  Process.runSync("git", ["commit", "-a", '-m "prepare $nextVersion"']);
  Process.runSync("git", ["tag", nextVersion.toString()]);
  Process.runSync("git", ["push", "-t"]);
  Process.runSync("apm", ["publish", "-t", nextVersion.toString()]);

  print("Version ${nextVersion} has been published!");
  print('¯\\_(ツ)_/¯');
}
