"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getAddress = exports.getDependencies = void 0;
const axios_1 = __importDefault(require("axios"));
const rest_1 = require("@octokit/rest");
const octokit = new rest_1.Octokit({
    auth: process.env.GITHUB_TOKEN,
});
const get_repo_id_by_package_name = async (name) => {
    const repo_path = await axios_1.default.get(`https://registry.npmjs.org/${name}`).then((res) => res.data);
    const info = repo_path.repository.url.match(/https:\/\/github.com\/(.*?)\/(.*)/);
    const repo = await octokit.request("GET /repos/{owner}/{repo}", {
        owner: info[1],
        repo: (info[2].replace('.git', '')).split('/')[0]
    });
    return repo.data.id;
};
const get_file = async (id, file) => {
    const repo = await octokit.request("GET /repositories/{id}", {
        id: id,
    });
    return await octokit.request("GET /repos/{owner}/{repo}/contents/{path}", {
        owner: repo.data.owner.login,
        repo: repo.data.name,
        path: file,
    });
};
const getDependencies = async (id) => {
    const file = await get_file(id, 'package.json');
    const data = file.data;
    const package_obj = await axios_1.default.get(data['download_url'], {
        method: "GET",
    }).then((res) => res.data);
    const list = [];
    if (package_obj.dependencies) {
        await getDependencyList(package_obj.dependencies, list);
    }
    return list;
};
exports.getDependencies = getDependencies;
const getAddress = async (id) => {
    var file;
    var address = "";
    try {
        file = await get_file(id, "address.pizza");
        const data = file.data;
        const content = await axios_1.default.get(data['download_url'], { method: "GET" }).then((res) => res.data);
        address = content.trim();
    }
    catch (err) {
        if (err.status === 404) {
            address = "";
        }
    }
    finally {
        return address;
    }
};
exports.getAddress = getAddress;
const getDependencyList = async (dependencies, list) => {
    if (!dependencies || Object.keys(dependencies).length == 0) {
        return list;
    }
    for (const dependency in dependencies) {
        const id = await get_repo_id_by_package_name(dependency);
        list.push(id);
        const file = await get_file(id, 'package.json');
        const data = file.data;
        const package_obj = await axios_1.default.get(data['download_url'], {
            method: "GET",
        }).then((res) => res.data);
        await getDependencyList(package_obj.dependencies, list);
    }
};
