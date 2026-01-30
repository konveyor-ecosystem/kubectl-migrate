package plugin

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"

	"github.com/konveyor/crane-lib/transform"
	binary_plugin "github.com/konveyor/crane-lib/transform/binary-plugin"
	"github.com/konveyor/crane-lib/transform/kubernetes"
	"github.com/sirupsen/logrus"
)

const (
	DefaultLocalPluginDir = "/.local/share/crane/plugins"
	GlobalPluginDir       = "/usr/local/share/crane/plugins"
	PkgPluginDir          = "/usr/share/crane/plugins"
)

// GetPlugins returns the plugins discovered under dir and always includes a KubernetesTransformPlugin.
// If dir does not exist, the default list (only the Kubernetes plugin) is returned. Any filesystem read
// errors or errors creating discovered binary plugins are propagated back to the caller.
// The function scans dir for executable binary plugins and appends them to the returned list.
func GetPlugins(dir string, logger *logrus.Logger) ([]transform.Plugin, error) {
	pluginList := []transform.Plugin{&kubernetes.KubernetesTransformPlugin{}}
	files, err := ioutil.ReadDir(dir)
	switch {
	case os.IsNotExist(err):
		return pluginList, nil
	case err != nil:
		return nil, err
	}
	list, err := getBinaryPlugins(dir, files, logger)
	if err != nil {
		return nil, err
	}
	pluginList = append(pluginList, list...)
	return pluginList, nil
}

// getBinaryPlugins traverses the given directory entries and returns any binary plugins it finds.
// It recursively descends into subdirectories and for each regular file with any execute permission
// attempts to create a binary plugin using binary_plugin.NewBinaryPlugin. It returns the collected
// plugins or the first error encountered.
func getBinaryPlugins(path string, files []os.FileInfo, logger *logrus.Logger) ([]transform.Plugin, error) {
	pluginList := []transform.Plugin{}
	for _, file := range files {
		filePath := fmt.Sprintf("%v/%v", path, file.Name())
		if file.IsDir() {
			newFiles, err := ioutil.ReadDir(filePath)
			if err != nil {
				return nil, err
			}
			plugins, err := getBinaryPlugins(filePath, newFiles, logger)
			if err != nil {
				return nil, err
			}
			pluginList = append(pluginList, plugins...)
		} else if file.Mode().IsRegular() && IsExecAny(file.Mode().Perm()) {
			newPlugin, err := binary_plugin.NewBinaryPlugin(filePath, logger)
			if err != nil {
				return nil, err
			}
			pluginList = append(pluginList, newPlugin)
		}
	}
	return pluginList, nil
}

// IsExecAny reports whether any execute permission bit (owner, group, or others) is set in mode.
func IsExecAny(mode os.FileMode) bool {
	return mode&0111 != 0
}

// GetFilteredPlugins collects plugins from multiple locations, deduplicates them by name, and excludes any whose names appear in skipPlugins.
// 
// It searches these paths (in order): the absolute "plugins" directory relative to the current working directory, the provided pluginDir,
// GlobalPluginDir, and PkgPluginDir. If skipPlugins is empty, all discovered plugins (deduplicated by Metadata().Name) are returned.
// If a filesystem or plugin-loading error occurs while discovering plugins, that error is returned.
func GetFilteredPlugins(pluginDir string, skipPlugins []string, logger *logrus.Logger) ([]transform.Plugin, error) {
	var filteredPlugins, unfilteredPlugins []transform.Plugin
	absPathPluginDir, err := filepath.Abs("plugins")
	if err != nil {
		return filteredPlugins, err
	}

	paths := []string{absPathPluginDir, pluginDir, GlobalPluginDir, PkgPluginDir}

	for _, path := range paths {
		plugins, err := GetPlugins(path, logger)
		if err != nil {
			return filteredPlugins, err
		}
		for _, newPlugin := range plugins {
			exists := false
			for _, plugin := range unfilteredPlugins {
				if plugin.Metadata().Name == newPlugin.Metadata().Name {
					exists = true
					break
				}
			}
			if !exists {
				unfilteredPlugins = append(unfilteredPlugins, newPlugin)
			}
		}
	}

	if len(skipPlugins) == 0 {
		return unfilteredPlugins, nil
	}
	for _, thisPlugin := range unfilteredPlugins {
		if !isPluginInList(thisPlugin, skipPlugins) {
			filteredPlugins = append(filteredPlugins, thisPlugin)
		}
	}
	return filteredPlugins, nil
}

// isPluginInList reports whether the plugin's metadata name appears in the provided list.
// It returns true if a matching name is found, false otherwise.
func isPluginInList(plugin transform.Plugin, list []string) bool {
	pluginName := plugin.Metadata().Name
	for _, listItem := range list {
		if pluginName == listItem {
			return true
		}
	}
	return false
}