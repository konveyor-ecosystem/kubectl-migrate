package plugin

import (
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/url"
	"os"
	"runtime"
	"strings"

	"github.com/ghodss/yaml"
	"github.com/sirupsen/logrus"
)

const (
	DEFAULT_REPO     = "default"
	DEFAULT_REPO_URL = "DEFAULT_REPO_URL"
	DEFAULT_URL      = "https://raw.githubusercontent.com/konveyor/crane-plugins/main/index.yaml"
)

// BuildManifestMap builds a map of plugin manifests keyed by repository and plugin name,
// where each entry contains the list of available plugin versions.
// If `name` is non-empty, only plugins whose names contain `name` are included.
// If `repoName` is non-empty, an error is returned because multiple repositories are not supported.
// When `repoName` is empty the default repository source is used.
// The returned map has the shape map[repoName][pluginName] = []PluginVersion.
func BuildManifestMap(log *logrus.Logger, name string, repoName string) (map[string]map[string][]PluginVersion, error) {
	// TODO: for multiple repo, read values from conf file to this map
	repos := make(map[string]string)

	if repoName != "" {
		// read the repo and url from the conf file and update the map with the same
		// repos[repoName] = <repoUrl>
		log.Errorf("Multiple repository is not supported right now so the flag --repo will not work till next release")
		return nil, errors.New("multiple repository is not supported right now so the flag --repo will not work till next release")
	} else {
		// read the whole config file and iterate through all repos to make sure every manifest is read
		repos[DEFAULT_REPO] = GetDefaultSource()
	}
	manifestMap := make(map[string]map[string][]PluginVersion)

	// iterate over all the repos
	for repo, url := range repos {
		// get the index.yml file for respective repo
		index, err := GetYamlFromUrl(url)
		if err != nil {
			return nil, err
		}
		// fetch all the manifest file from a repo
		for _, p := range index.Plugins {
			// retrieve the manifest if name matches or there is no name passed, i.e a specific or all of the manifest
			if name == "" || strings.Contains(p.Name, name) {
				plugin, err := YamlToManifest(p.Path)
				if err != nil {
					log.Errorf("Error reading %s plugin manifest located at %s - Error: %s", p.Name, p.Path, err)
					return nil, err
				}
				if _, ok := manifestMap[repo]; ok {
					manifestMap[repo][p.Name] = plugin
				} else {
					manifestMap[repo] = make(map[string][]PluginVersion)
					manifestMap[repo][p.Name] = plugin
				}
			}
		}
	}
	return manifestMap, nil
}

// GetYamlFromUrl retrieves an index YAML from the given URL and unmarshals it into a PluginIndex.
// It returns an error if the data cannot be read or the YAML cannot be parsed.
func GetYamlFromUrl(URL string) (PluginIndex, error) {
	var manifest PluginIndex
	index, err := getData(URL)
	if err != nil {
		return manifest, err
	}
	err = yaml.Unmarshal(index, &manifest)
	if err != nil {
		return manifest, err
	}
	return manifest, nil
}

// YamlToManifest loads a plugin manifest from the given URL and returns the versions
// that have binaries matching the current OS and architecture.
//
// If the manifest cannot be read or parsed, an error is returned. If the manifest
// is valid but contains no binaries for the current OS/architecture, an empty
// slice is returned (no error).
func YamlToManifest(URL string) ([]PluginVersion, error) {
	plugin := Plugin{}

	body, err := getData(URL)
	if err != nil {
		return plugin.Versions, err
	}

	err = yaml.Unmarshal(body, &plugin)
	if err != nil {
		return []PluginVersion{}, err
	}

	isPluginAvailable := FilterPluginForOsArch(&plugin)
	if isPluginAvailable {
		return plugin.Versions, nil
	}
	// TODO: figure out a better way to not return the plugin
	return []PluginVersion{}, nil
}

// FilterPluginForOsArch filters the given plugin's versions so each version retains only the binary that matches the current GOOS/GOARCH.
// It mutates the provided Plugin in place and returns `true` if at least one matching binary was found, `false` otherwise.
func FilterPluginForOsArch(plugin *Plugin) bool {
	// filter manifests for current os/arch
	isPluginAvailable := false
	for _, version := range plugin.Versions {
		for _, binary := range version.Binaries {
			if binary.OS == runtime.GOOS && binary.Arch == runtime.GOARCH {
				isPluginAvailable = true
				version.Binaries = []Binary{
					binary,
				}
				break
			}
		}
	}
	return isPluginAvailable
}

// GetDefaultSource returns the default plugin repository URL.
// If the environment variable DEFAULT_REPO_URL is set, its value is used; otherwise DEFAULT_URL is returned.
func GetDefaultSource() string {
	val, present := os.LookupEnv(DEFAULT_REPO_URL)
	if present {
		return val
	}
	return DEFAULT_URL
}

// LocateBinaryInPluginDir returns the full paths of executable files named name found in the provided files slice within pluginDir.
// The returned paths are constructed as "pluginDir/<filename>" and include only regular files with executable permissions.
func LocateBinaryInPluginDir(pluginDir string, name string, files []os.FileInfo) ([]string, error) {
	paths := []string{}

	for _, file := range files {
		filePath := fmt.Sprintf("%v/%v", pluginDir, file.Name())
		if file.Mode().IsRegular() && IsExecAny(file.Mode().Perm()) && file.Name() == name {
			paths = append(paths, filePath)
		}
	}
	return paths, nil
}

// IsUrl reports whether s is a URL and returns a normalized string with any leading
// "file://" prefix removed. It returns true when the normalized value contains a URL
// scheme and host, and false otherwise.
func IsUrl(URL string) (bool, string) {
	URL = strings.TrimPrefix(URL, "file://")
	u, err := url.Parse(URL)
	return err == nil && u.Scheme != "" && u.Host != "", URL
}

// getData reads raw bytes from the given URL or local file path.
// If the input parses as an HTTP(S) URL it performs a GET request and returns the response body; otherwise it reads the file at the given path. It returns the read bytes or an error encountered during retrieval.
func getData(URL string) ([]byte, error) {
	var index []byte
	var err error
	isUrl, URL := IsUrl(URL)
	if !isUrl {
		index, err = ioutil.ReadFile(URL)
		if err != nil {
			return nil, err
		}
	} else {
		res, err := http.Get(URL)
		if err != nil {
			return nil, err
		}

		defer res.Body.Close()

		index, err = ioutil.ReadAll(res.Body)
		if err != nil {
			return nil, err
		}
	}
	return index, nil
}